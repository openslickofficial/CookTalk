"""
CookTalk Phase 2 — LiveKit Streaming Voice Agent
Pipeline:
  - STT: Deepgram (nova-3 streaming)
  - LLM: Groq via OpenAI-compatible plugin (qwen/qwen3.8-27b, streaming)
  - TTS: Rime via WebSocket streaming (/ws3, model: coda, speaker: astra)
  - VAD: Silero ONNX turn detection
  - Orchestrator: LiveKit Agents 1.x AgentSession
"""

import asyncio
import io
import json
import logging
import os
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

# Safe encoding for Windows console
if sys.stdout and hasattr(sys.stdout, "buffer"):
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    except Exception:
        pass

from dotenv import load_dotenv

env_path_parent = Path(__file__).resolve().parent.parent / ".env"
env_path_local = Path(__file__).resolve().parent / ".env"
if env_path_local.exists():
    load_dotenv(dotenv_path=env_path_local)
elif env_path_parent.exists():
    load_dotenv(dotenv_path=env_path_parent)
else:
    load_dotenv()

import wave
from livekit import rtc
from livekit.agents import (
    Agent,
    AgentSession,
    APIConnectOptions,
    APIConnectionError,
    APIStatusError,
    ConversationItemAddedEvent,
    JobContext,
    MetricsCollectedEvent,
    UserInputTranscribedEvent,
    WorkerOptions,
    cli,
    llm,
    tts,
)
from livekit.agents.types import DEFAULT_API_CONNECT_OPTIONS
from livekit.agents.tts import ChunkedStream, FallbackAdapter, StreamAdapter
from livekit.agents.metrics import (
    EOUMetrics,
    LLMMetrics,
    STTMetrics,
    TTSMetrics,
)
from livekit.plugins import deepgram, openai, rime, silero

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("cooktalk-agent")

STREAMING_RESULTS_FILE = Path(__file__).resolve().parent / "streaming_results.jsonl"
FALLBACK_WAV = Path(__file__).resolve().parent / "fallback_error_24k.wav"


class LocalFallbackChunkedStream(ChunkedStream):
    """Streams a pre-recorded emergency fallback WAV when primary TTS fails."""

    def __init__(self, tts_instance, text: str, wav_path: Path):
        super().__init__(tts=tts_instance, input_text=text, conn_options=DEFAULT_API_CONNECT_OPTIONS)
        self.wav_path = wav_path

    async def _run(self, output_emitter: tts.AudioEmitter) -> None:
        logger.warning(
            "[FALLBACK ACTIVATED] Rime TTS failed or unreachable — speaking pre-recorded local fallback audio."
        )
        with wave.open(str(self.wav_path), "rb") as wf:
            sr = wf.getframerate()
            nch = wf.getnchannels()
            pcm_bytes = wf.readframes(wf.getnframes())

        output_emitter.initialize(
            request_id="local_fallback",
            sample_rate=sr,
            num_channels=nch,
            mime_type="audio/pcm",
            stream=True,
        )
        output_emitter.start_segment(segment_id="seg_fallback")

        chunk_size = int(sr * 0.02) * nch * 2
        for offset in range(0, len(pcm_bytes), chunk_size):
            chunk = pcm_bytes[offset : offset + chunk_size]
            if chunk:
                output_emitter.push(chunk)
                await asyncio.sleep(0.001)

        output_emitter.end_segment()


class LocalFallbackTTS(tts.TTS):
    """Local non-streaming fallback TTS backed by a pre-recorded audio notice."""

    def __init__(self, wav_path: Path):
        super().__init__(
            capabilities=tts.TTSCapabilities(streaming=False),
            sample_rate=24000,
            num_channels=1,
        )
        self.wav_path = wav_path

    def synthesize(self, text: str, *, conn_options=DEFAULT_API_CONNECT_OPTIONS) -> ChunkedStream:
        return LocalFallbackChunkedStream(self, text, self.wav_path)


class WarmRimeTTS(rime.TTS):
    """
    Rime TTS with active WebSocket connection warming and stale socket rotation.
    
    The controlled idle sweep (A1) proved that Rime's remote endpoint drops idle
    WebSockets between 15s and 20s (threshold at ~18s).
    WarmRimeTTS:
    1. Configures max_session_duration=12.0s on the connection pool so idle sockets
       are gracefully retired and prewarmed BEFORE the server-side teardown occurs.
    2. Runs an active background connection keeper that tests socket health and
       prewarms a fresh warm connection if idle for >10s.
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Set max_session_duration to 12s (well under the 18s server-side idle timeout)
        self._pool._max_session_duration = 12.0
        self._warming_task: asyncio.Task | None = None
        self._last_use_time = time.time()

    def stream(self, *, conn_options=DEFAULT_API_CONNECT_OPTIONS):
        self._last_use_time = time.time()
        # Evict dead/closing sockets before stream acquisition
        for conn in list(self._pool._available):
            if conn.closed or getattr(conn, "_closed", False):
                self._pool.remove(conn)
        return super().stream(conn_options=conn_options)

    def start_keepalive(self):
        """Starts background keepalive worker to maintain a warm socket."""
        if self._warming_task is not None and not self._warming_task.done():
            return

        async def _keepalive_loop():
            logger.info("[WARM RIME TTS] Keepalive monitor active (10s warming interval).")
            while True:
                try:
                    await asyncio.sleep(4.0)
                    idle_dur = time.time() - self._last_use_time

                    # Discard any socket marked closed
                    for conn in list(self._pool._available):
                        if conn.closed or getattr(conn, "_closed", False):
                            self._pool.remove(conn)

                    # If idle for >10s or pool is empty, prewarm fresh socket
                    if idle_dur >= 10.0 or not self._pool._available:
                        # If existing available socket is older than 11s, rotate it
                        now = time.time()
                        for conn in list(self._pool._available):
                            conn_age = now - self._pool._connections.get(conn, now)
                            if conn_age >= 11.0:
                                self._pool.remove(conn)
                        self._pool.prewarm()
                except asyncio.CancelledError:
                    break
                except Exception as e:
                    logger.debug(f"[WARM RIME TTS] Keepalive notice: {e}")

        self._warming_task = asyncio.create_task(_keepalive_loop())

    async def aclose(self):
        if self._warming_task:
            self._warming_task.cancel()
        await super().aclose()

RECIPES_FILE = Path(__file__).resolve().parent / "recipes.json"
GENERATED_FILE = Path(__file__).resolve().parent / "generated_dishes.json"


def load_all_recipes() -> dict:
    data = {}
    if RECIPES_FILE.exists():
        try:
            with open(RECIPES_FILE, "r", encoding="utf-8") as f:
                data.update(json.load(f))
        except Exception as e:
            logger.warning(f"Error reading recipes.json: {e}")
    if GENERATED_FILE.exists():
        try:
            with open(GENERATED_FILE, "r", encoding="utf-8") as f:
                data.update(json.load(f))
        except Exception as e:
            logger.warning(f"Error reading generated_dishes.json: {e}")
    return data


RECIPES_DATA = load_all_recipes()

COOKING_CO_PILOT_PROMPT = """You are CookTalk, an expert hands-free voice cooking assistant for cooks with busy or messy hands.
CRITICAL SPEAKING STYLE:
- Speak 1-2 brief, conversational sentences (strictly under 20-25 words). Never monologue.
- Multi-item lists: When sharing ingredients, name ONLY the 2-3 most essential items conversationally and offer to continue (e.g., "For Cacio e Pepe, you'll need spaghetti, pecorino, and black pepper, plus a couple pantry items. Want the rest?"). Never recite a full 5-ingredient list in one turn.
- Direct & punchy: Be helpful, warm, and concise.

DIETARY & ALLERGY SAFEGUARD (HIGHEST PRIORITY):
- The user has loaded their allergy profile at session start. NEVER suggest ingredients they are allergic to.
- When substituting ingredients, ALWAYS use `check_ingredient_safety` first if the user asks "Can I use X?" or suggests a specific ingredient.
- If user proposes a dangerous ingredient (e.g., "Can I use peanut oil?" when they have peanut allergy), immediately warn them using the safety check tool.
- The `suggest_substitution` tool automatically filters out allergenic options. Trust its filtered results.
- Safety comes FIRST - never compromise on allergen avoidance.

CRITICAL-VALUE CONFIRMATION (TASK 5):
- For timer durations and temperature values specifically, ALWAYS confirm the parsed number back before committing.
- Example: User says "set a timer for 50 minutes" → You respond "Setting a 50-minute timer — that's right?" and wait for confirmation.
- Example: User says "heat to 375 degrees" → You respond "Got it, 375 degrees Fahrenheit — correct?" and confirm before proceeding.
- Do NOT add this friction to non-critical queries (ingredients, substitutions, general questions).

Rules & Capabilities:
1. Catalog Recipes: If the user asks about or switches to a dish in your catalog (scrambled eggs, cacio e pepe, ribeye steak, cookies, tikka masala, pancakes, salmon, tacos), call `set_active_recipe` or step tools so the interactive UI tracks along.
2. ANY Culinary Dish or Question: You know thousands of recipes, techniques, cooking temps, and baking ratios! If the user asks how to cook ANY dish or asks any cooking question (even outside the catalog), answer directly and expertly in 1-2 punchy sentences.
3. Step Navigation: 
   - Call `next_step` to advance forward
   - Call `previous_step` to go back
   - Call `repeat_step` to repeat current step
   - Call `peek_next_step` to preview what's next WITHOUT advancing
   - Call `jump_to_step(step_number)` for arbitrary navigation to any step
   - Call `get_current_step` for current step info
4. Ingredients & Substitutions: Call `get_ingredient_quantity` or `suggest_substitution`. If not in the active recipe, answer using your culinary knowledge.
5. Ingredient Safety: When user asks "Can I use [ingredient]?" or suggests using something specific, call `check_ingredient_safety` FIRST.
6. Timers (Multi-Timer Support):
   - Call `start_cooking_timer` whenever the user asks for a timer
   - Call `cancel_cooking_timer` to stop a timer
   - Call `get_timer_remaining` to check remaining time (read-only)
   - Call `modify_timer(new_duration, label)` to change total duration
   - Call `extend_timer(add_seconds, label)` to add time
   - CRITICAL: If 2+ timers active and command doesn't specify which (e.g., "add 5 minutes"), ASK which timer by name. Never guess or default to most recent.
7. Serving Changes: If asked to change servings mid-recipe, decline cleanly: "Let's finish this batch — I'll scale the next one."
8. Session End: When user says goodbye phrases ("that's it", "I'm done", "stop", "thanks bye", "goodbye", "see you later"), call `end_session`. If timers are active, you will be prompted to confirm.
9. Repeat: When repeat_step is called, recite the instruction verbatim without paraphrasing.
10. Out of scope: Only decline non-cooking topics (e.g. coding, politics) politely in one sentence.
"""

SYSTEM_PROMPT = COOKING_CO_PILOT_PROMPT

RIME_MODEL = "coda"
RIME_SPEAKER = "astra"
GROQ_MODEL = os.getenv("GROQ_MODEL", "qwen/qwen3.8-27b")
DEEPGRAM_MODEL = "nova-3"

TOOL_ACKNOWLEDGMENTS = {
    "get_ingredient_quantity": [
        "Checking the measurements for you.",
        "Looking up that amount.",
        "One sec, checking the recipe.",
    ],
    "get_recipe_ingredients": [
        "Checking the ingredients list for you.",
        "Looking up the ingredients now.",
        "One sec, checking that recipe.",
    ],
    "suggest_substitution": [
        "Let me check good substitutions for that.",
        "Looking up what you can swap in.",
        "One moment, checking substitute options.",
    ],
    "next_step": [
        "Moving to the next step.",
        "Next up.",
        "Getting the next step.",
    ],
    "previous_step": [
        "Going back one step.",
        "Backing up a step.",
    ],
    "repeat_step": [
        "Repeating that step for you.",
        "One sec, repeating.",
    ],
    "peek_next_step": [
        "Let me check what's coming up.",
        "Looking ahead for you.",
    ],
    "jump_to_step": [
        "Jumping to that step.",
        "Moving there now.",
    ],
    "set_active_recipe": [
        "Getting that recipe ready.",
        "Pulling up that recipe now.",
    ],
    "start_cooking_timer": [
        "Setting that timer right now.",
        "Starting your timer.",
    ],
    "cancel_cooking_timer": [
        "Cancelling that timer for you.",
        "Stopping your timer now.",
    ],
    "get_timer_remaining": [
        "Checking timer status.",
        "Looking up remaining time.",
    ],
    "modify_timer": [
        "Modifying that timer.",
        "Updating the timer duration.",
    ],
    "extend_timer": [
        "Adding time to your timer.",
        "Extending that timer.",
    ],
    "end_session": [
        "Wrapping up for you.",
        "Ending the session.",
    ],
    "get_current_step": [
        "Checking where we are.",
        "Looking up the current step.",
    ],
}


class CookingCoPilot:
    """Manages active recipe state, step navigation, ingredient queries, and proactive timers."""

    def __init__(self, recipes: dict):
        self.recipes = recipes
        self.active_recipe_id = None  # Start with no recipe loaded
        self.current_step_index = 0  # 0 indicates no active recipe
        self.session: AgentSession | None = None
        self.room: rtc.Room | None = None
        self.active_timers: dict[str, asyncio.Task] = {}
        self.active_timer_metadata: dict[str, dict] = {}
        self.has_explicit_recipe = False
        self._timer_alert_lock = asyncio.Lock()
        self._agent_speaking_lock = asyncio.Lock()
        
        # TASK 2: Idle session timeout tracking
        self._last_user_speech_time: float = time.time()
        self._idle_monitor_task: asyncio.Task | None = None
        self._idle_timeout_seconds: float = 300.0  # 5 minutes
        
        # Dietary & Pantry Allergy Safeguard
        self.user_allergies: list[str] = []
        self.user_dislikes: list[str] = []
        self.dietary_restrictions: list[str] = []

    def load_user_dietary_profile(self, allergies: list[str] = None, dislikes: list[str] = None, restrictions: list[str] = None):
        """Load user's dietary restrictions, allergies, and dislikes for real-time safety filtering."""
        self.user_allergies = [a.lower().strip() for a in (allergies or [])]
        self.user_dislikes = [d.lower().strip() for d in (dislikes or [])]
        self.dietary_restrictions = [r.lower().strip() for r in (restrictions or [])]
        logger.info(f"[ALLERGY SAFEGUARD] Loaded dietary profile: Allergies={self.user_allergies}, Dislikes={self.user_dislikes}, Restrictions={self.dietary_restrictions}")

    def check_ingredient_safety(self, ingredient: str) -> tuple[bool, str | None]:
        """
        Real-time safety check for ingredient against user allergies.
        Returns: (is_safe, warning_message)
        
        WARNING: This uses basic string matching + common synonyms.
        It is NOT a substitute for reading ingredient labels yourself.
        """
        # Common allergen synonyms (major allergens FDA Top 9)
        ALLERGEN_SYNONYMS = {
            'peanut': ['peanut', 'groundnut', 'arachis', 'goober', 'monkey nut'],
            'tree nut': ['almond', 'cashew', 'walnut', 'pecan', 'pistachio', 'hazelnut', 'macadamia', 'brazil nut', 'pine nut'],
            'milk': ['milk', 'dairy', 'casein', 'whey', 'lactose', 'butter', 'cream', 'cheese', 'yogurt', 'ghee'],
            'egg': ['egg', 'albumin', 'lysozyme', 'ovalbumin', 'ovomucin'],
            'soy': ['soy', 'soya', 'edamame', 'tofu', 'tempeh', 'miso', 'natto', 'lecithin'],
            'wheat': ['wheat', 'flour', 'gluten', 'semolina', 'spelt', 'farina', 'graham', 'durum'],
            'fish': ['fish', 'anchovy', 'bass', 'cod', 'flounder', 'halibut', 'salmon', 'tuna', 'trout'],
            'shellfish': ['shellfish', 'shrimp', 'crab', 'lobster', 'crayfish', 'prawn', 'clam', 'mussel', 'oyster', 'scallop'],
            'sesame': ['sesame', 'tahini', 'benne', 'gingelly', 'til'],
        }
        
        ing_lower = ingredient.lower().strip()
        
        # Check severe allergies first (highest priority)
        for allergen in self.user_allergies:
            allergen_lower = allergen.lower().strip()
            
            # Direct match
            if allergen_lower in ing_lower or ing_lower in allergen_lower:
                warning = f"CAUTION: Your profile lists a severe {allergen} allergy. Do NOT use {ingredient}."
                logger.warning(f"[ALLERGY SAFEGUARD] [!] BLOCKED dangerous ingredient: {ingredient} (allergen: {allergen})")
                return (False, warning)
            
            # Synonym match
            for category, synonyms in ALLERGEN_SYNONYMS.items():
                if allergen_lower in synonyms or any(syn in allergen_lower for syn in synonyms):
                    # User's allergen matches this category, check ingredient against all synonyms
                    for syn in synonyms:
                        if syn in ing_lower:
                            warning = f"CAUTION: Your profile lists a severe {allergen} allergy. {ingredient} contains {syn}. Do NOT use it."
                            logger.warning(f"[ALLERGY SAFEGUARD] [!] BLOCKED dangerous ingredient: {ingredient} (synonym: {syn}, allergen: {allergen})")
                            return (False, warning)
        
        return (True, None)

    def filter_substitutions(self, candidates: list[str]) -> tuple[list[str], list[str]]:
        """
        Filter substitution candidates against user allergies.
        Returns: (safe_substitutions, blocked_items_with_reasons)
        """
        safe = []
        blocked = []
        
        for candidate in candidates:
            is_safe, warning = self.check_ingredient_safety(candidate)
            if is_safe:
                safe.append(candidate)
            else:
                blocked.append(f"{candidate} (blocked: allergy)")
                
        return (safe, blocked)

    def set_session(self, session: AgentSession) -> None:
        self.session = session

    def set_room(self, room: rtc.Room) -> None:
        self.room = room
    
    def record_user_speech(self) -> None:
        """Record user speech activity to reset idle timer."""
        self._last_user_speech_time = time.time()
    
    def start_idle_monitor(self) -> None:
        """
        TASK 2: Start background idle session monitor.
        
        Timeout: 5 minutes (300 seconds) of no user speech AND no active timers.
        
        Rationale: Protects LiveKit budget (1,000 min/month) from abandoned sessions
        while allowing legitimate timer-waiting scenarios. 5 minutes balances:
        - Short enough to catch abandoned sessions quickly
        - Long enough for user to check recipe on phone, wash hands, prep ingredients
        - Does NOT interrupt active timer countdowns (even if silent)
        """
        if self._idle_monitor_task and not self._idle_monitor_task.done():
            return
        
        async def _idle_monitor_loop():
            logger.info(f"[IDLE MONITOR] Started. Timeout: {self._idle_timeout_seconds}s (no speech + no timers).")
            while True:
                try:
                    await asyncio.sleep(30.0)  # Check every 30 seconds
                    
                    # If active timers running, NOT idle (even if no speech)
                    if self.active_timers:
                        continue
                    
                    # Calculate idle duration since last user speech
                    idle_duration = time.time() - self._last_user_speech_time
                    
                    # If exceeded threshold with no timers, disconnect
                    if idle_duration >= self._idle_timeout_seconds:
                        logger.warning(f"[IDLE MONITOR] Session idle for {idle_duration:.1f}s with no active timers. Ending session.")
                        
                        if self.session:
                            try:
                                await self.session.say(
                                    "Hey Chef, you've been quiet for a while and no timers are running. I'm closing this session to save resources. Come back anytime!",
                                    allow_interruptions=False,
                                    add_to_chat_ctx=True,
                                )
                                await asyncio.sleep(2.0)  # Let message finish
                            except Exception as e:
                                logger.debug(f"[IDLE MONITOR] Could not speak goodbye: {e}")
                        
                        await self.broadcast({
                            "type": "session_ended",
                            "message": "Session ended due to inactivity",
                            "reason": "idle_timeout"
                        })
                        
                        # Signal session should close
                        break
                        
                except asyncio.CancelledError:
                    logger.info("[IDLE MONITOR] Monitor cancelled.")
                    break
                except Exception as e:
                    logger.debug(f"[IDLE MONITOR] Check error: {e}")
        
        self._idle_monitor_task = asyncio.create_task(_idle_monitor_loop())
    
    def stop_idle_monitor(self) -> None:
        """Stop idle monitor (called on explicit session end)."""
        if self._idle_monitor_task:
            self._idle_monitor_task.cancel()
            self._idle_monitor_task = None

    def speak_acknowledgment(self, tool_name: str) -> None:
        """Trigger an immediate spoken acknowledgment via Rime when tool execution starts."""
        if not self.session:
            return
        phrases = TOOL_ACKNOWLEDGMENTS.get(tool_name, ["Checking that now.", "One sec, looking that up."])
        import random
        phrase = random.choice(phrases)
        logger.info(f"[TOOL ACKNOWLEDGMENT] Speaking via Rime: '{phrase}' for tool '{tool_name}'")
        try:
            self.session.say(phrase, add_to_chat_ctx=False)
            metrics_manager.notify_acknowledgment_spoken(tool_name, phrase)
        except Exception as e:
            logger.warning(f"[TOOL ACKNOWLEDGMENT] Could not schedule acknowledgment: {e}")

    async def speak_connection_issue(self, message: str = "You're facing a connection issue — reconnecting now."):
        """TASK 7: Speak connection issue notice through normal utterance channel (not error UI)."""
        if self.session:
            try:
                logger.warning(f"[CONNECTION ISSUE] Speaking notice: {message}")
                await self.session.say(message, allow_interruptions=False, add_to_chat_ctx=True)
            except Exception as e:
                logger.error(f"[CONNECTION ISSUE] Failed to speak notice: {e}")

    async def broadcast(self, data: dict):
        """Broadcast real-time culinary state to connected WebRTC client."""
        if self.room and self.room.local_participant:
            try:
                payload = json.dumps(data)
                await self.room.local_participant.publish_data(payload, topic="cooktalk")
                logger.info(f"[BROADCAST] Sent data channel event: {data.get('type')}")
            except Exception as e:
                logger.debug(f"[BROADCAST] Data publish notice: {e}")
                # TASK 7: If broadcast fails due to connection issue, speak it
                if "connection" in str(e).lower() or "timeout" in str(e).lower():
                    await self.speak_connection_issue()

    @property
    def active_recipe(self) -> dict:
        if self.active_recipe_id is None:
            return {}  # Return empty dict when no recipe is active
        return self.recipes.get(self.active_recipe_id, {})

    def get_tools(self) -> list[llm.FunctionTool]:
        copilot = self

        def track_tool(fnc):
            fnc_name = fnc.__name__
            import functools
            @functools.wraps(fnc)
            async def wrapped(*args, **kwargs):
                t_start = time.perf_counter()
                metrics_manager.notify_tool_call_start(fnc_name)
                copilot.speak_acknowledgment(fnc_name)
                try:
                    res = await fnc(*args, **kwargs)
                    return res
                finally:
                    dur_ms = (time.perf_counter() - t_start) * 1000.0
                    metrics_manager.notify_tool_call_end(fnc_name, dur_ms)
            return wrapped

        @llm.function_tool
        @track_tool
        async def set_active_recipe(recipe_name_or_id: str) -> str:
            """Select or switch the active recipe (e.g. 'chocolate chip cookies', 'cacio e pepe', 'ribeye steak', 'pancakes', 'scrambled eggs', 'tikka masala', 'salmon', 'tacos')."""
            target = recipe_name_or_id.strip().lower()
            matched_id = None
            for k, r in copilot.recipes.items():
                if k in target or target in k or r["name"].lower() in target or target in r["name"].lower():
                    matched_id = k
                    break
                for word in target.replace("-", " ").replace("_", " ").split():
                    if len(word) > 3 and (word in k or word in r["name"].lower()):
                        matched_id = k
                        break
                if matched_id:
                    break

            if matched_id:
                copilot.active_recipe_id = matched_id
                copilot.current_step_index = 1
                recipe = copilot.active_recipe
                steps = recipe.get("steps", [])
                await copilot.broadcast({
                    "type": "recipe_state",
                    "recipe_id": copilot.active_recipe_id,
                    "recipe_name": recipe["name"],
                    "current_step": 1,
                    "total_steps": len(steps),
                    "instruction": steps[0]["instruction"] if steps else "",
                })
                return f"Switched to {recipe['name']}. We are at Step 1: {recipe['steps'][0]['instruction']}"
            
            # TASK 1: Clean decline for unmatched dishes (no improvised guidance, no generation)
            return f"I don't have {recipe_name_or_id} in my recipe catalog. Pick a dish from the app and we'll start cooking together."

        @llm.function_tool
        @track_tool
        async def get_current_step() -> str:
            """Get current recipe instruction."""
            if copilot.active_recipe_id is None:
                return "No recipe selected yet. Please tell me what you'd like to cook, or select a dish from the app."
            
            recipe = copilot.active_recipe
            steps = recipe.get("steps", [])
            if not steps:
                return "No recipe steps loaded."
            idx = max(1, min(copilot.current_step_index, len(steps)))
            step = steps[idx - 1]
            await copilot.broadcast({
                "type": "recipe_state",
                "recipe_id": copilot.active_recipe_id,
                "recipe_name": recipe["name"],
                "current_step": idx,
                "total_steps": len(steps),
                "instruction": step["instruction"],
            })
            return f"Step {step['step_number']} of {len(steps)} for {recipe['name']}: {step['instruction']}"

        @llm.function_tool
        @track_tool
        async def next_step() -> str:
            """Advance to next recipe step."""
            if copilot.active_recipe_id is None:
                return "No recipe selected yet. Please tell me what you'd like to cook, or select a dish from the app."
            
            recipe = copilot.active_recipe
            steps = recipe.get("steps", [])
            if not steps:
                return "No steps loaded."
            if copilot.current_step_index < len(steps):
                copilot.current_step_index += 1
                step = steps[copilot.current_step_index - 1]
                await copilot.broadcast({
                    "type": "recipe_state",
                    "recipe_id": copilot.active_recipe_id,
                    "recipe_name": recipe["name"],
                    "current_step": copilot.current_step_index,
                    "total_steps": len(steps),
                    "instruction": step["instruction"],
                })
                return f"Step {step['step_number']}: {step['instruction']}"
            return f"That was the final step for {recipe['name']}! Your dish is complete and ready to enjoy."

        @llm.function_tool
        @track_tool
        async def previous_step() -> str:
            """Go to previous recipe step."""
            if copilot.active_recipe_id is None:
                return "No recipe selected yet. Please tell me what you'd like to cook, or select a dish from the app."
            
            recipe = copilot.active_recipe
            steps = recipe.get("steps", [])
            if not steps:
                return "No steps loaded."
            if copilot.current_step_index > 1:
                copilot.current_step_index -= 1
                step = steps[copilot.current_step_index - 1]
                await copilot.broadcast({
                    "type": "recipe_state",
                    "recipe_id": copilot.active_recipe_id,
                    "recipe_name": recipe["name"],
                    "current_step": copilot.current_step_index,
                    "total_steps": len(steps),
                    "instruction": step["instruction"],
                })
                return f"Back to Step {step['step_number']}: {step['instruction']}"
            return f"You are already at Step 1: {steps[0]['instruction']}"

        @llm.function_tool
        @track_tool
        async def repeat_step() -> str:
            """Repeat current step instruction verbatim."""
            if copilot.active_recipe_id is None:
                return "No recipe selected yet. Please tell me what you'd like to cook, or select a dish from the app."
            
            recipe = copilot.active_recipe
            steps = recipe.get("steps", [])
            if not steps:
                return "No recipe steps loaded."
            idx = max(1, min(copilot.current_step_index, len(steps)))
            step = steps[idx - 1]
            await copilot.broadcast({
                "type": "recipe_state",
                "recipe_id": copilot.active_recipe_id,
                "recipe_name": recipe["name"],
                "current_step": idx,
                "total_steps": len(steps),
                "instruction": step["instruction"],
            })
            return f"{step['instruction']}"

        @llm.function_tool
        @track_tool
        async def get_ingredient_quantity(ingredient_name: str) -> str:
            """Get quantity of an ingredient in active recipe or advise general proportions."""
            if copilot.active_recipe_id is None:
                return "No recipe selected yet. Please tell me what you'd like to cook, or select a dish from the app."
            
            recipe = copilot.active_recipe
            target = ingredient_name.strip().lower()
            for ing in recipe.get("ingredients", []):
                if target in ing["name"].lower() or ing["name"].lower() in target:
                    return f"For {recipe['name']}, you need {ing['quantity']} {ing['unit']} of {ing['name']}."
            for r_id, r in copilot.recipes.items():
                for ing in r.get("ingredients", []):
                    if target in ing["name"].lower() or ing["name"].lower() in target:
                        return f"{ing['quantity']} {ing['unit']} in {r['name']}"
            # TASK 3 FIX: Add grounding signal for unverified quantities
            return f"I don't have {ingredient_name.title()} in my saved recipes. If you know typical proportions, answer with 'Generally' or 'Typically' to signal this is from culinary knowledge, not the active recipe."

        @llm.function_tool
        @track_tool
        async def suggest_substitution(ingredient_name: str) -> str:
            """Suggest substitution for an ingredient in active recipe or any general culinary ingredient."""
            if copilot.active_recipe_id is None:
                return "No recipe selected yet. Please tell me what you'd like to cook, or select a dish from the app."
            
            recipe = copilot.active_recipe
            target = ingredient_name.strip().lower()
            
            # Build list of candidate substitutions
            candidates = []
            substitutions = recipe.get("substitutions", {})
            for ing_key, sub_val in substitutions.items():
                if target in ing_key.lower() or ing_key.lower() in target:
                    # Parse multiple options if comma-separated
                    candidates.extend([s.strip() for s in sub_val.split(",")])
                    break
            
            # If no preset, check other recipes
            if not candidates:
                for r_id, r in copilot.recipes.items():
                    for ing_key, sub_val in r.get("substitutions", {}).items():
                        if target in ing_key.lower() or ing_key.lower() in target:
                            candidates.extend([s.strip() for s in sub_val.split(",")])
                            break
                    if candidates:
                        break
            
            # Apply Allergy Safeguard filter
            if copilot.user_allergies and candidates:
                safe_options, blocked = copilot.filter_substitutions(candidates)
                
                if not safe_options:
                    # All options blocked - immediate safety warning
                    warning_msg = f"All substitutions for {ingredient_name} contain allergens from your profile. Recommend alternatives: use olive oil, vegetable oil, or water-based substitutes depending on the recipe."
                    logger.warning(f"[ALLERGY SAFEGUARD] All {ingredient_name} substitutions blocked")
                    return warning_msg
                
                if blocked:
                    # Some options blocked - return only safe ones
                    logger.info(f"[ALLERGY SAFEGUARD] Filtered substitutions for {ingredient_name}: Safe={safe_options}, Blocked={blocked}")
                    candidates = safe_options
            
            # Return filtered safe substitutions
            if candidates:
                options_str = " or ".join(candidates[:3])  # Limit to 3 options for voice clarity
                return f"For {ingredient_name}: try {options_str}"
            
            # TASK 2 FIX: Fallback to LLM, but add uncertainty signal + allergen warning
            allergen_warning = ""
            if copilot.user_allergies:
                allergen_list = ", ".join(copilot.user_allergies)
                allergen_warning = f" IMPORTANT: Please verify any suggestion against your allergy profile ({allergen_list}) before using it - I can't filter improvised substitutions."
            
            return f"I don't have {ingredient_name} in my recipe database.{allergen_warning} You can suggest common culinary alternatives, but prefix with 'Generally,' to signal this is ungrounded knowledge."

        @llm.function_tool
        @track_tool
        async def check_ingredient_safety(ingredient_name: str) -> str:
            """Check if an ingredient is safe for the user based on their allergy profile. Call this when user asks 'Can I use [ingredient]?' or suggests using a specific ingredient."""
            is_safe, warning = copilot.check_ingredient_safety(ingredient_name)
            
            if not is_safe:
                # Immediate high-priority safety warning via Rime
                logger.error(f"[ALLERGY SAFEGUARD] WARNING USER PROPOSED DANGEROUS INGREDIENT: {ingredient_name}")
                # Add disclaimer to every warning
                return f"{warning} Remember, this is a best-effort check and not a substitute for reading ingredient labels yourself."
            
            # Add disclaimer even when safe
            return f"{ingredient_name} appears safe based on your dietary profile, but this is a best-effort check only. Always verify ingredients yourself when you have severe allergies."

        @llm.function_tool
        @track_tool
        async def start_cooking_timer(duration_seconds: int, label: str) -> str:
            """Start cooking timer in seconds."""
            secs = max(1, int(duration_seconds))
            clean_label = label.strip() or "cooking step"

            expires = time.time() + secs
            copilot.active_timer_metadata[clean_label] = {
                "label": clean_label,
                "duration_seconds": secs,
                "expires_at": expires,
            }

            # Broadcast timer start immediately to UI
            await copilot.broadcast({
                "type": "timer_started",
                "label": clean_label,
                "duration_seconds": secs,
                "expires_at": expires,
            })

            async def timer_task():
                try:
                    await asyncio.sleep(secs)
                    logger.info(f"[TIMER EXPIRED] Timer '{clean_label}' ({secs}s) finished. Emitting proactive voice alert.")
                    await copilot.broadcast({
                        "type": "timer_completed",
                        "label": clean_label,
                    })
                    if copilot.session:
                        # TASK 6: Queue timer alert - wait for any ongoing agent speech to complete
                        async with copilot._agent_speaking_lock:
                            async with copilot._timer_alert_lock:
                                await copilot.session.say(
                                    f"Ding ding! Your timer for {clean_label} is done.",
                                    allow_interruptions=True,
                                    add_to_chat_ctx=True,
                                )
                                await asyncio.sleep(0.4)
                                # TASK 2 FIX: Reset idle clock after timer alert so user gets fresh 5-min window
                                copilot.record_user_speech()
                except asyncio.CancelledError:
                    logger.info(f"[TIMER CANCELLED] Timer '{clean_label}' was cancelled.")
                except Exception as e:
                    logger.error(f"[TIMER ERROR] Failed to announce timer alert: {e}")
                finally:
                    copilot.active_timers.pop(clean_label, None)
                    copilot.active_timer_metadata.pop(clean_label, None)

            t = asyncio.create_task(timer_task())
            copilot.active_timers[clean_label] = t
            mins = secs // 60
            rem_secs = secs % 60
            time_str = f"{mins} minute{'s' if mins != 1 else ''}" if rem_secs == 0 else f"{secs} seconds"
            return f"Timer started for {time_str} for {clean_label}. I will tell you when it's done."

        @llm.function_tool
        @track_tool
        async def cancel_cooking_timer(label: str | None = None) -> str:
            """Cancel or stop an active cooking timer. Call this whenever the user says 'cancel timer', 'stop timer', 'turn off timer', or 'cancel the [label] timer'."""
            if not copilot.active_timers:
                return "You don't have any active timers running right now."

            target_label = None
            if label:
                clean_target = label.strip().lower()
                for k in list(copilot.active_timers.keys()):
                    if clean_target in k.lower() or k.lower() in clean_target:
                        target_label = k
                        break

            # If not matched or no label specified, cancel the only running timer or the most recent
            if not target_label and copilot.active_timers:
                target_label = list(copilot.active_timers.keys())[-1]

            if target_label and target_label in copilot.active_timers:
                task = copilot.active_timers.pop(target_label)
                copilot.active_timer_metadata.pop(target_label, None)
                task.cancel()
                logger.info(f"[TIMER CANCELLED] Manually cancelled timer for '{target_label}'.")
                await copilot.broadcast({
                    "type": "timer_cancelled",
                    "label": target_label,
                })
                return f"Cancelled the timer for {target_label}."
            elif target_label:
                copilot.active_timer_metadata.pop(target_label, None)
                await copilot.broadcast({
                    "type": "timer_cancelled",
                    "label": target_label,
                })
                return f"Cancelled the timer for {target_label}."

            return "No matching timer found to cancel."
        
        # ========== TASK 2: MULTI-TIMER TOOLKIT ==========
        
        @llm.function_tool
        @track_tool
        async def get_timer_remaining(label: str | None = None) -> str:
            """Get remaining time on a timer (read-only, doesn't change state). If label not specified and multiple timers active, lists all timers."""
            if not copilot.active_timer_metadata:
                return "No active timers running right now."
            
            # If no label specified and multiple timers, list all
            if not label and len(copilot.active_timer_metadata) > 1:
                timer_list = []
                now = time.time()
                for lbl, meta in copilot.active_timer_metadata.items():
                    remaining = max(0, int(meta["expires_at"] - now))
                    mins = remaining // 60
                    secs = remaining % 60
                    time_str = f"{mins}:{secs:02d}" if mins > 0 else f"{secs} seconds"
                    timer_list.append(f"{lbl}: {time_str}")
                return "Active timers: " + ", ".join(timer_list)
            
            # Find specific timer
            target_label = None
            if label:
                clean_target = label.strip().lower()
                for k in copilot.active_timer_metadata.keys():
                    if clean_target in k.lower() or k.lower() in clean_target:
                        target_label = k
                        break
            else:
                # Single timer, get it
                target_label = list(copilot.active_timer_metadata.keys())[0] if copilot.active_timer_metadata else None
            
            if target_label and target_label in copilot.active_timer_metadata:
                now = time.time()
                meta = copilot.active_timer_metadata[target_label]
                remaining = max(0, int(meta["expires_at"] - now))
                mins = remaining // 60
                secs = remaining % 60
                time_str = f"{mins} minute{'s' if mins != 1 else ''} and {secs} seconds" if mins > 0 else f"{secs} seconds"
                return f"{target_label} has {time_str} remaining."
            
            return f"No timer found matching '{label}'." if label else "No active timer found."
        
        @llm.function_tool
        @track_tool
        async def modify_timer(new_duration_seconds: int, label: str | None = None) -> str:
            """Modify a timer to a new total duration. If multiple timers active and no label specified, MUST ask which one."""
            if not copilot.active_timers:
                return "No active timers to modify."
            
            # Multi-timer disambiguation check
            if len(copilot.active_timers) > 1 and not label:
                timer_names = ", ".join(copilot.active_timers.keys())
                return f"You have {len(copilot.active_timers)} timers running ({timer_names}). Which one do you want to modify?"
            
            # Find target timer
            target_label = None
            if label:
                clean_target = label.strip().lower()
                for k in copilot.active_timers.keys():
                    if clean_target in k.lower() or k.lower() in clean_target:
                        target_label = k
                        break
            else:
                target_label = list(copilot.active_timers.keys())[0]
            
            if not target_label or target_label not in copilot.active_timers:
                return f"No timer found matching '{label}'." if label else "No active timer found."
            
            # Cancel old timer
            old_task = copilot.active_timers.pop(target_label)
            old_task.cancel()
            
            # Start new timer with modified duration
            new_secs = max(1, int(new_duration_seconds))
            expires = time.time() + new_secs
            copilot.active_timer_metadata[target_label] = {
                "label": target_label,
                "duration_seconds": new_secs,
                "expires_at": expires,
            }
            
            await copilot.broadcast({
                "type": "timer_started",
                "label": target_label,
                "duration_seconds": new_secs,
                "expires_at": expires,
            })
            
            async def timer_task():
                try:
                    await asyncio.sleep(new_secs)
                    logger.info(f"[TIMER EXPIRED] Timer '{target_label}' ({new_secs}s) finished.")
                    await copilot.broadcast({"type": "timer_completed", "label": target_label})
                    if copilot.session:
                        # TASK 6: Queue timer alert - wait for any ongoing agent speech to complete
                        async with copilot._agent_speaking_lock:
                            async with copilot._timer_alert_lock:
                                await copilot.session.say(
                                    f"Ding ding! Your timer for {target_label} is done.",
                                    allow_interruptions=True,
                                    add_to_chat_ctx=True,
                                )
                                await asyncio.sleep(0.4)
                                # TASK 2 FIX: Reset idle clock after timer alert (modify_timer path)
                                copilot.record_user_speech()
                except asyncio.CancelledError:
                    logger.info(f"[TIMER CANCELLED] Timer '{target_label}' cancelled.")
                except Exception as e:
                    logger.error(f"[TIMER ERROR] Failed to announce: {e}")
                finally:
                    copilot.active_timers.pop(target_label, None)
                    copilot.active_timer_metadata.pop(target_label, None)
            
            t = asyncio.create_task(timer_task())
            copilot.active_timers[target_label] = t
            
            mins = new_secs // 60
            rem_secs = new_secs % 60
            time_str = f"{mins} minute{'s' if mins != 1 else ''}" if rem_secs == 0 else f"{new_secs} seconds"
            return f"Modified {target_label} timer to {time_str}."
        
        @llm.function_tool
        @track_tool
        async def extend_timer(add_seconds: int, label: str | None = None) -> str:
            """Add time to an existing timer. If multiple timers active and no label specified, MUST ask which one."""
            if not copilot.active_timers:
                return "No active timers to extend."
            
            # Multi-timer disambiguation check
            if len(copilot.active_timers) > 1 and not label:
                timer_names = ", ".join(copilot.active_timers.keys())
                return f"You have {len(copilot.active_timers)} timers running ({timer_names}). Which one do you want to extend?"
            
            # Find target timer
            target_label = None
            if label:
                clean_target = label.strip().lower()
                for k in copilot.active_timers.keys():
                    if clean_target in k.lower() or k.lower() in clean_target:
                        target_label = k
                        break
            else:
                target_label = list(copilot.active_timers.keys())[0]
            
            if not target_label or target_label not in copilot.active_timer_metadata:
                return f"No timer found matching '{label}'." if label else "No active timer found."
            
            # Calculate new duration (current remaining + added time)
            now = time.time()
            meta = copilot.active_timer_metadata[target_label]
            current_remaining = max(0, int(meta["expires_at"] - now))
            new_total = current_remaining + max(1, int(add_seconds))
            
            # Restart with extended time
            old_task = copilot.active_timers.pop(target_label)
            old_task.cancel()
            
            expires = time.time() + new_total
            copilot.active_timer_metadata[target_label] = {
                "label": target_label,
                "duration_seconds": new_total,
                "expires_at": expires,
            }
            
            await copilot.broadcast({
                "type": "timer_started",
                "label": target_label,
                "duration_seconds": new_total,
                "expires_at": expires,
            })
            
            async def timer_task():
                try:
                    await asyncio.sleep(new_total)
                    logger.info(f"[TIMER EXPIRED] Timer '{target_label}' ({new_total}s) finished.")
                    await copilot.broadcast({"type": "timer_completed", "label": target_label})
                    if copilot.session:
                        # TASK 6: Queue timer alert - wait for any ongoing agent speech to complete
                        async with copilot._agent_speaking_lock:
                            async with copilot._timer_alert_lock:
                                await copilot.session.say(
                                    f"Ding ding! Your timer for {target_label} is done.",
                                    allow_interruptions=True,
                                    add_to_chat_ctx=True,
                                )
                                await asyncio.sleep(0.4)
                                # TASK 2 FIX: Reset idle clock after timer alert (extend_timer path)
                                copilot.record_user_speech()
                except asyncio.CancelledError:
                    logger.info(f"[TIMER CANCELLED] Timer '{target_label}' cancelled.")
                except Exception as e:
                    logger.error(f"[TIMER ERROR] Failed to announce: {e}")
                finally:
                    copilot.active_timers.pop(target_label, None)
                    copilot.active_timer_metadata.pop(target_label, None)
            
            t = asyncio.create_task(timer_task())
            copilot.active_timers[target_label] = t
            
            add_mins = add_seconds // 60
            add_secs = add_seconds % 60
            add_str = f"{add_mins} minute{'s' if add_mins != 1 else ''}" if add_secs == 0 else f"{add_seconds} seconds"
            return f"Added {add_str} to {target_label}. New total: {new_total // 60} minutes {new_total % 60} seconds."
        
        # ========== TASK 3: STEP NAVIGATION REFINEMENT ==========
        
        @llm.function_tool
        @track_tool
        async def peek_next_step() -> str:
            """Preview what the next step is WITHOUT advancing. Use when user asks 'what's next' but doesn't want to move forward yet."""
            if copilot.active_recipe_id is None:
                return "No recipe selected yet. Please tell me what you'd like to cook, or select a dish from the app."
            
            recipe = copilot.active_recipe
            steps = recipe.get("steps", [])
            if not steps:
                return "No recipe steps loaded."
            
            next_idx = copilot.current_step_index + 1
            if next_idx <= len(steps):
                next_step = steps[next_idx - 1]
                return f"Next up is Step {next_step['step_number']}: {next_step['instruction']}"
            return f"Step {copilot.current_step_index} is the final step."
        
        @llm.function_tool
        @track_tool
        async def jump_to_step(step_number: int) -> str:
            """Jump directly to a specific step number (arbitrary navigation, not just sequential)."""
            if copilot.active_recipe_id is None:
                return "No recipe selected yet. Please tell me what you'd like to cook, or select a dish from the app."
            
            recipe = copilot.active_recipe
            steps = recipe.get("steps", [])
            if not steps:
                return "No recipe steps loaded."
            
            target = max(1, min(step_number, len(steps)))
            if target != step_number:
                return f"Step {step_number} is out of range. This recipe has {len(steps)} steps."
            
            copilot.current_step_index = target
            step = steps[target - 1]
            
            await copilot.broadcast({
                "type": "recipe_state",
                "recipe_id": copilot.active_recipe_id,
                "recipe_name": recipe["name"],
                "current_step": target,
                "total_steps": len(steps),
                "instruction": step["instruction"],
            })
            
            return f"Jumped to Step {step['step_number']}: {step['instruction']}"
        
        # ========== TASK 1: SESSION END WITH TIMER HANDLING ==========
        
        @llm.function_tool
        @track_tool
        async def end_session() -> str:
            """End the cooking session. Call when user says goodbye phrases like 'that's it', 'I'm done', 'stop', 'thanks bye', 'goodbye', 'see you later', etc."""
            # Check for active timers
            if copilot.active_timers:
                timer_list = ", ".join(copilot.active_timers.keys())
                timer_count = len(copilot.active_timers)
                
                # Timer-on-exit behavior: FLAG IT, don't silently discard
                # DESIGN DECISION: Warn user and ask for confirmation before ending
                return f"Wait! You still have {timer_count} active timer{'s' if timer_count > 1 else ''} running ({timer_list}). End session anyway? Say 'yes' to confirm or 'cancel' to keep cooking."
            
            # No active timers - safe to end
            copilot.stop_idle_monitor()  # TASK 2: Stop idle monitor on explicit session end
            await copilot.broadcast({
                "type": "session_ended",
                "message": "Session ended by user"
            })
            return "Happy cooking! See you next time."

        @llm.function_tool
        @track_tool
        async def get_recipe_ingredients(recipe_name_or_id: str | None = None) -> str:
            """Get ingredients for a specific dish or recipe (e.g. 'chocolate chip cookies', 'cacio e pepe', 'pancakes', 'ribeye steak', 'salmon', 'tacos', 'scrambled eggs'). Pass the name of the dish if mentioned."""
            target = recipe_name_or_id.strip().lower() if recipe_name_or_id else ""
            matched_id = None
            if target:
                for k, r in copilot.recipes.items():
                    if k in target or target in k or r["name"].lower() in target or target in r["name"].lower():
                        matched_id = k
                        break
                    for word in target.replace("-", " ").replace("_", " ").split():
                        if len(word) > 3 and (word in k or word in r["name"].lower()):
                            matched_id = k
                            break
                    if matched_id:
                        break
            else:
                matched_id = copilot.active_recipe_id

            if matched_id and matched_id in copilot.recipes:
                copilot.active_recipe_id = matched_id
                copilot.current_step_index = 1
                recipe = copilot.recipes[matched_id]
                ings = recipe.get("ingredients", [])
                main_ings = ", ".join(f"{i['quantity']} {i['unit']} {i['name']}" for i in ings[:3])
                remainder = len(ings) - 3
                if remainder > 0:
                    return f"Key ingredients for {recipe['name']}: {main_ings}, plus {remainder} other items. Offer to share the full list."
                return f"Ingredients for {recipe['name']}: {main_ings}."

            # TASK 3 FIX: Add grounding signal for dishes not in catalog
            return f"I don't have {recipe_name_or_id} in my recipe catalog. If you know the essential ingredients from culinary experience, share them but start with 'Generally you'll need' or 'Typically' to signal this isn't from verified recipe data."

        return [
            set_active_recipe,
            get_current_step,
            next_step,
            previous_step,
            repeat_step,
            peek_next_step,
            jump_to_step,
            get_ingredient_quantity,
            get_recipe_ingredients,
            suggest_substitution,
            check_ingredient_safety,
            start_cooking_timer,
            cancel_cooking_timer,
            get_timer_remaining,
            modify_timer,
            extend_timer,
            end_session,
        ]


def sanitize_chat_context(chat_ctx: llm.ChatContext) -> llm.ChatContext:
    """Collapses consecutive user messages and ensures valid chat template structure for Groq/Qwen."""
    truncated = chat_ctx.copy()
    if len(truncated.items) > 8:
        truncated.truncate(max_items=8)
    new_items: list[llm.ChatItem] = []
    has_user = False
    for item in truncated.items:
        if isinstance(item, llm.ChatMessage):
            if item.role == "user":
                has_user = True
                if (
                    new_items
                    and isinstance(new_items[-1], llm.ChatMessage)
                    and new_items[-1].role == "user"
                ):
                    logger.info(
                        f"[CONTEXT SANITIZE] Replaced un-replied user message with latest: '{item.text_content}'"
                    )
                    new_items[-1] = item
                else:
                    new_items.append(item)
            else:
                new_items.append(item)
        else:
            new_items.append(item)

    # Qwen chat template requires at least one user query if assistant/tool turns exist
    if not has_user and new_items:
        # Prepend a fallback user message to satisfy Qwen Jinja template requirements
        new_items.insert(0, llm.ChatMessage(role="user", content=["Continue."]))

    return llm.ChatContext(items=new_items)



def parse_retry_after(error: Exception) -> float | None:
    """Extracts rate limit reset time (in seconds) from error body or message."""
    msg = ""
    if hasattr(error, "body") and isinstance(error.body, dict):
        msg = error.body.get("message", "")
    if not msg and hasattr(error, "message"):
        msg = str(error.message)
    if not msg:
        msg = str(error)

    match = re.search(r"try again in ([0-9.]+)\s*(ms|s)", msg, re.IGNORECASE)
    if match:
        val = float(match.group(1))
        unit = match.group(2).lower()
        return val / 1000.0 if unit == "ms" else val
    return None


class DynamicGroqConnectOptions(APIConnectOptions):
    """Dynamically adapts retry backoff: respects Groq 429 Retry-After hints capped at 14.0s,
    while using fast 0.5s backoff for generic transient errors."""

    def __init__(self, stream_ref=None, max_retry=2, timeout=18.0, max_cap=14.0):
        super().__init__(max_retry=max_retry, retry_interval=0.5, timeout=timeout)
        self.stream_ref = stream_ref
        self.max_cap = max_cap

    def _interval_for_retry(self, num_retries: int) -> float:
        err = getattr(self.stream_ref, "_last_run_error", None)
        if err:
            is_429 = (isinstance(err, APIStatusError) and err.status_code == 429) or ("rate_limit" in str(err).lower())
            if is_429:
                hint = parse_retry_after(err)
                if hint is not None:
                    delay = min(max(hint + 0.15, 0.5), self.max_cap)
                    logger.warning(
                        f"[GROQ 429 BACKOFF] Parsed Retry-After hint={hint:.2f}s. Sleeping dynamic delay={delay:.2f}s (cap={self.max_cap}s) before retry #{num_retries + 1}."
                    )
                    return delay
                logger.warning(
                    f"[GROQ 429 BACKOFF] 429 rate limit without hint. Sleeping default 1.5s before retry #{num_retries + 1}."
                )
                return 1.5
        logger.info(f"[GROQ TRANSIENT BACKOFF] Generic/empty completion. Sleeping fast 0.5s before retry #{num_retries + 1}.")
        return 0.5


class RetryingGroqStream(openai.llm.LLMStream):
    """Custom stream for Groq that detects empty completions, parses rate-limit guidance,
    and automatically retries with intelligent backoff before falling back to audible notice."""

    MAX_RATE_LIMIT_BACKOFF_SEC = 14.0

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._extra_kwargs["max_tokens"] = 60
        self._extra_kwargs["max_completion_tokens"] = 60
        self._last_run_error = None
        self._attempts_count = 0
        self._is_fallback = False
        self._conn_options = DynamicGroqConnectOptions(
            self,
            max_retry=2,
            timeout=18.0,
            max_cap=self.MAX_RATE_LIMIT_BACKOFF_SEC,
        )

    async def _run(self) -> None:
        self._attempts_count += 1
        has_content = False
        old_send = self._event_ch.send_nowait

        def tracking_send(chunk: llm.ChatChunk):
            nonlocal has_content
            if chunk.has_response():
                has_content = True
            old_send(chunk)

        self._event_ch.send_nowait = tracking_send
        try:
            await super()._run()
            has_tools = bool(getattr(self, "_tool_call_id", None) or getattr(self, "_fnc_name", None))
            if not has_content and not has_tools:
                req_id = ""
                if hasattr(self, "_oai_stream") and self._oai_stream and hasattr(self._oai_stream, "response"):
                    req_id = self._oai_stream.response.headers.get("x-request-id", "")
                err = APIStatusError(
                    "Groq returned empty completion (0 content tokens)",
                    status_code=200,
                    request_id=req_id,
                    body=None,
                    retryable=True,
                )
                self._last_run_error = err
                raise err
            # Successful completion
            metrics_manager.record_llm_attempt_result(self._attempts_count, is_fallback=False)
        except Exception as e:
            self._last_run_error = e
            raise
        finally:
            self._event_ch.send_nowait = old_send

    async def _main_task(self) -> None:
        try:
            await super()._main_task()
        except Exception as e:
            logger.error(
                f"[LLM EXHAUSTED] All Groq retry attempts ({self._attempts_count}) failed: {e}. Emitting audible fallback notice."
            )
            self._is_fallback = True
            metrics_manager.record_llm_attempt_result(self._attempts_count, is_fallback=True)
            fallback_chunk = llm.ChatChunk(
                id="llm_fallback_msg",
                delta=llm.ChoiceDelta(
                    role="assistant",
                    content="I am having trouble connecting to the cooking assistant right now. Please ask again in a moment.",
                ),
            )
            self._event_ch.send_nowait(fallback_chunk)


class RetryingGroqLLM(openai.LLM):
    """Groq LLM with context sanitization, empty completion detection, and auto-retry."""

    def chat(
        self,
        *,
        chat_ctx: llm.ChatContext,
        tools: list[llm.Tool] | None = None,
        conn_options: APIConnectOptions = DEFAULT_API_CONNECT_OPTIONS,
        **kwargs,
    ) -> openai.llm.LLMStream:
        sanitized_ctx = sanitize_chat_context(chat_ctx)
        effective_conn = APIConnectOptions(max_retry=2, retry_interval=0.5, timeout=18.0)
        stream = super().chat(
            chat_ctx=sanitized_ctx,
            tools=tools,
            conn_options=effective_conn,
            **kwargs,
        )
        return RetryingGroqStream(
            self,
            model=stream._model,
            provider_fmt=stream._provider_fmt,
            strict_tool_schema=stream._strict_tool_schema,
            client=stream._client,
            chat_ctx=sanitized_ctx,
            tools=stream._tools,
            conn_options=effective_conn,
            extra_kwargs=stream._extra_kwargs,
        )


class TurnMetricsManager:
    """Manages turn correlation and metrics logging for streaming results."""

    def __init__(self, results_file: Path):
        self.results_file = results_file
        self.turns = {}  # speech_id -> dict of metrics
        self.latest_speech_id = None
        self.last_user_transcript = ""
        self.last_assistant_response = ""
        self.turn_llm_start_time = None
        self.current_tool_name = None
        self.current_tool_duration_ms = None
        self.tool_call_roundtrip_ms = None

    def get_or_create(self, speech_id: str | None) -> dict:
        sid = speech_id or self.latest_speech_id or "turn_default"
        if sid not in self.turns:
            self.turns[sid] = {
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "speech_id": sid,
                "text": "",
                "agent_response": "",
                "eou_delay_ms": None,
                "llm_ttft_ms": None,
                "tts_ttfb_ms": None,
                "tts_audio_duration_ms": None,
                "tts_duration_ms": None,
                "latency_ms": None,
                "status": "pending",
                "resolution": "pending",
                "llm_attempts": 1,
                "tool_called": None,
                "tool_execution_ms": None,
                "tool_roundtrip_ms": None,
                "tts_provider": "rime",
                "tts_model": RIME_MODEL,
                "tts_speaker": RIME_SPEAKER,
                "streaming": True,
                "protocol": "websocket_ws3",
            }
        self.latest_speech_id = sid
        return self.turns[sid]

    def notify_tool_call_start(self, tool_name: str):
        self.current_tool_name = tool_name
        sid = self.latest_speech_id or "turn_default"
        turn = self.get_or_create(sid)
        turn["tool_called"] = tool_name
        logger.info(f"[TOOL START] Tool '{tool_name}' invoked.")

    def notify_tool_call_end(self, tool_name: str, duration_ms: float):
        self.current_tool_duration_ms = duration_ms
        sid = self.latest_speech_id or "turn_default"
        turn = self.get_or_create(sid)
        turn["tool_called"] = tool_name
        turn["tool_execution_ms"] = round(duration_ms, 1)
        logger.info(f"[TOOL COMPLETED] Tool '{tool_name}' finished in {duration_ms:.1f} ms.")

    def notify_acknowledgment_spoken(self, tool_name: str, phrase: str):
        now = time.perf_counter()
        sid = self.latest_speech_id or "turn_default"
        turn = self.get_or_create(sid)
        turn["acknowledgment_phrase"] = phrase
        if self.turn_llm_start_time is not None:
            turn["acknowledgment_latency_ms"] = round((now - self.turn_llm_start_time) * 1000.0, 1)
        else:
            turn["acknowledgment_latency_ms"] = None
        logger.info(
            f"[TOOL ACKNOWLEDGMENT RECORDED] Phrase: '{phrase}' (Latency: {turn.get('acknowledgment_latency_ms')} ms)"
        )

    def record_llm_attempt_result(self, attempts: int, is_fallback: bool):
        turn = self.get_or_create(self.latest_speech_id)
        turn["llm_attempts"] = attempts
        if is_fallback:
            turn["resolution"] = "unanswered_fallback_apology"
        elif attempts > 1:
            turn["resolution"] = "answered_retry_assisted"
        else:
            turn["resolution"] = "answered_first_attempt"

    def record_user_transcript(self, transcript: str):
        if transcript.strip():
            self.last_user_transcript = transcript.strip()
            turn = self.get_or_create(self.latest_speech_id)
            turn["text"] = self.last_user_transcript

    def record_assistant_response(self, text: str):
        clean_text = text.strip()
        if not clean_text:
            return
        self.last_assistant_response = clean_text
        sid = self.latest_speech_id or "turn_default"
        if sid in self.turns:
            self.turns[sid]["agent_response"] = clean_text
            if hasattr(self, "on_turn_completed") and self.on_turn_completed:
                try:
                    self.on_turn_completed(self.turns[sid])
                except Exception as e:
                    logger.debug(f"[METRICS CALLBACK] Error in turn callback: {e}")

        # Retroactively update latest line in results_file if agent_response was empty
        try:
            if self.results_file.exists():
                lines = self.results_file.read_text(encoding="utf-8").splitlines()
                if lines:
                    last_obj = json.loads(lines[-1])
                    if not last_obj.get("agent_response") or last_obj.get("speech_id") == sid:
                        last_obj["agent_response"] = clean_text
                        lines[-1] = json.dumps(last_obj)
                        self.results_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
                        logger.info(f"[METRICS] Retroactively updated agent_response in {self.results_file.name}: '{clean_text[:40]}...'")
        except Exception as e:
            logger.warning(f"[METRICS] Failed updating agent_response in JSONL: {e}")

    def record_eou(self, metrics: EOUMetrics):
        turn = self.get_or_create(metrics.speech_id)
        if metrics.end_of_utterance_delay is not None:
            turn["eou_delay_ms"] = round(metrics.end_of_utterance_delay * 1000, 1)
        self.turn_llm_start_time = time.perf_counter()
        self.current_tool_name = None
        self.current_tool_duration_ms = None
        self.tool_call_roundtrip_ms = None
        logger.info(f"[VAD/EOU] End of utterance delay: {turn['eou_delay_ms']} ms")

    def record_llm(self, metrics: LLMMetrics):
        turn = self.get_or_create(metrics.speech_id)
        now = time.perf_counter()
        if turn.get("tool_called") and self.turn_llm_start_time is not None:
            roundtrip = (now - self.turn_llm_start_time) * 1000.0
            turn["tool_roundtrip_ms"] = round(roundtrip, 1)
            turn["llm_ttft_ms"] = round(metrics.ttft * 1000, 1) if metrics.ttft is not None else None
            turn["status"] = "success"
            logger.info(
                f"[TOOL OVERHEAD MEASURED] Tool: {turn['tool_called']} | Exec: {turn.get('tool_execution_ms')} ms | Total Roundtrip: {turn['tool_roundtrip_ms']} ms | LLM2 TTFT: {turn['llm_ttft_ms']} ms"
            )
        else:
            # Guard against negative sentinels (e.g. -1.0 -> -1000.0 ms)
            if metrics.ttft is not None and metrics.ttft >= 0:
                turn["llm_ttft_ms"] = round(metrics.ttft * 1000, 1)
                turn["status"] = "success"
            else:
                turn["llm_ttft_ms"] = None
                turn["status"] = "llm_empty_completion"

            tps = metrics.tokens_per_second if hasattr(metrics, "tokens_per_second") and metrics.tokens_per_second else 0.0
            logger.info(
                f"[LLM Groq {GROQ_MODEL}] TTFT: {turn['llm_ttft_ms']} ms | Tokens/sec: {tps:.1f} | Status: {turn['status']}"
            )

    def record_tts(self, metrics: TTSMetrics):
        turn = self.get_or_create(metrics.speech_id)
        if metrics.ttfb is not None:
            turn["tts_ttfb_ms"] = round(metrics.ttfb * 1000, 1)
        if metrics.audio_duration is not None:
            turn["tts_audio_duration_ms"] = round(metrics.audio_duration * 1000, 1)
        if metrics.duration is not None:
            turn["tts_duration_ms"] = round(metrics.duration * 1000, 1)

        # Check resolution based on response content
        resp = turn.get("agent_response", "")
        if "trouble connecting" in resp.lower() or turn.get("resolution") == "unanswered_fallback_apology":
            turn["resolution"] = "unanswered_fallback_apology"
        elif turn.get("llm_attempts", 1) > 1:
            turn["resolution"] = "answered_retry_assisted"
        else:
            turn["resolution"] = "answered_first_attempt"

        # Perceived End-to-End Latency:
        eou = turn.get("eou_delay_ms")
        ttft = turn.get("llm_ttft_ms")
        ttfb = turn.get("tts_ttfb_ms")
        tool_rt = turn.get("tool_roundtrip_ms")

        # Guard against None or invalid sentinels:
        if tool_rt is not None and ttfb is not None:
            e2e_ms = round((eou or 0.0) + tool_rt + ttfb, 1)
            turn["latency_ms"] = e2e_ms
            turn["status"] = "success"
        elif ttft is not None and ttfb is not None and ttft >= 0:
            e2e_ms = round((eou or 0.0) + ttft + ttfb, 1)
            turn["latency_ms"] = e2e_ms
            turn["status"] = "success"
        else:
            turn["latency_ms"] = None
            if turn.get("status") != "llm_empty_completion":
                turn["status"] = "incomplete"

        # Active provider observability rule:
        logger.info(
            f"[ACTIVE TTS PROVIDER: RIME] Model: {RIME_MODEL} | Voice: {RIME_SPEAKER} | Protocol: WebSocket /ws3"
        )
        logger.info(
            f"[STREAMING TURN MEASURED] E2E Perceived: {turn['latency_ms']} ms (EOU: {eou} ms | LLM TTFT: {ttft} ms | Tool RT: {tool_rt} ms | Rime TTFB: {ttfb} ms) | Status: {turn['status']}"
        )

        try:
            with open(self.results_file, "a", encoding="utf-8") as f:
                f.write(json.dumps(turn) + "\n")
            logger.info(f"[METRICS] Recorded turn to {self.results_file.name}")
        except Exception as e:
            logger.error(f"Error writing to JSONL: {e}")

        if hasattr(self, "on_turn_completed") and self.on_turn_completed:
            try:
                self.on_turn_completed(turn)
            except Exception as e:
                logger.debug(f"[METRICS CALLBACK] Error in turn callback: {e}")

        # Retain bounded history of turns instead of deleting immediately
        if len(self.turns) > 50:
            oldest_key = next(iter(self.turns))
            del self.turns[oldest_key]


metrics_manager = TurnMetricsManager(STREAMING_RESULTS_FILE)


class CookTalkAgent(Agent):
    def __init__(self, tools: list[llm.FunctionTool] | None = None):
        super().__init__(instructions=SYSTEM_PROMPT, tools=tools)

    async def on_enter(self) -> None:
        logger.info("[AGENT] CookTalk Agent is active and listening for cooking questions.")


async def entrypoint(ctx: JobContext):
    logger.info("Connecting to LiveKit room...")
    await ctx.connect()
    logger.info(f"Connected to room: {ctx.room.name}")

    rime_key = os.getenv("RIME_API_KEY")
    groq_key = os.getenv("GROQ_API_KEY")
    deepgram_key = os.getenv("DEEPGRAM_API_KEY")

    if not rime_key:
        raise ValueError("RIME_API_KEY is not set in environment.")
    if not groq_key:
        raise ValueError("GROQ_API_KEY is not set in environment.")
    if not deepgram_key:
        raise ValueError("DEEPGRAM_API_KEY is not set in environment.")

    # Instantiate cooking co-pilot state and tools
    copilot = CookingCoPilot(RECIPES_DATA)
    tools = copilot.get_tools()

    # STT: Deepgram streaming
    stt_plugin = deepgram.STT(
        model=DEEPGRAM_MODEL,
        language="en-US",
        api_key=deepgram_key,
    )

    # LLM: Groq via RetryingGroqLLM with automatic retry, backoff, and chat context sanitization
    llm_plugin = RetryingGroqLLM(
        model=GROQ_MODEL,
        base_url="https://api.groq.com/openai/v1",
        api_key=groq_key,
        max_completion_tokens=60,
    )

    # TTS: Rime official plugin with true WebSocket streaming (/ws3), active connection warming, and local fallback
    rime_primary = WarmRimeTTS(
        model=RIME_MODEL,
        speaker=RIME_SPEAKER,
        use_websocket=True,
        api_key=rime_key,
    )
    rime_primary.start_keepalive()
    fallback_local = StreamAdapter(tts=LocalFallbackTTS(FALLBACK_WAV))
    tts_plugin = FallbackAdapter(tts=[rime_primary, fallback_local], max_retry_per_tts=1)

    # VAD: Silero local neural model
    vad_plugin = silero.VAD.load()

    logger.info(
        f"[PIPELINE INITIALIZED] STT=Deepgram({DEEPGRAM_MODEL}) | LLM=RetryingGroqLLM({GROQ_MODEL}) | TTS=WarmRimeTTS({RIME_MODEL}/{RIME_SPEAKER} via WebSocket /ws3 with LocalFallback)"
    )

    session = AgentSession(
        vad=vad_plugin,
        stt=stt_plugin,
        llm=llm_plugin,
        tts=tts_plugin,
        tools=tools,
        min_endpointing_delay=0.6,
        preemptive_generation=False,
    )
    copilot.set_session(session)
    copilot.set_room(ctx.room)

    def notify_turn(turn):
        asyncio.create_task(copilot.broadcast({
            "type": "turn_metrics",
            "eou_delay_ms": turn.get("eou_delay_ms"),
            "llm_ttft_ms": turn.get("llm_ttft_ms"),
            "tts_ttfb_ms": turn.get("tts_ttfb_ms"),
            "latency_ms": turn.get("latency_ms"),
            "agent_response": turn.get("agent_response"),
            "status": turn.get("status"),
            "tool_called": turn.get("tool_called"),
            "tool_execution_ms": turn.get("tool_execution_ms"),
            "tool_roundtrip_ms": turn.get("tool_roundtrip_ms"),
            "acknowledgment_phrase": turn.get("acknowledgment_phrase"),
            "acknowledgment_latency_ms": turn.get("acknowledgment_latency_ms"),
        }))

    metrics_manager.on_turn_completed = notify_turn

    @session.on("user_input_transcribed")
    def on_transcription(ev: UserInputTranscribedEvent):
        if ev.is_final:
            metrics_manager.record_user_transcript(ev.transcript)
            copilot.record_user_speech()  # TASK 2: Reset idle timer on user speech

    @session.on("conversation_item_added")
    def on_conversation_item(ev: ConversationItemAddedEvent):
        # Keep sliding history window so LLM context stays fast and responsive
        try:
            if len(session.history.items) > 8:
                session.history.truncate(max_items=8)
        except Exception:
            pass

        role = getattr(ev.item, "role", "")
        text = getattr(ev.item, "text_content", "") or ""
        if not text and hasattr(ev.item, "content"):
            c = ev.item.content
            if isinstance(c, list):
                text = " ".join(str(x) for x in c)
            else:
                text = str(c)
        if role == "user":
            metrics_manager.record_user_transcript(text)
        elif role == "assistant":
            metrics_manager.record_assistant_response(text)

    @session.on("metrics_collected")
    def on_metrics(ev: MetricsCollectedEvent):
        m = ev.metrics
        if isinstance(m, EOUMetrics):
            metrics_manager.record_eou(m)
        elif isinstance(m, LLMMetrics):
            metrics_manager.record_llm(m)
        elif isinstance(m, TTSMetrics):
            metrics_manager.record_tts(m)

    @ctx.room.on("data_received")
    def on_data_received(data_packet: rtc.DataPacket):
        try:
            payload = json.loads(data_packet.data.decode("utf-8"))
            msg_type = payload.get("type")
            
            # Load user dietary profile on session start
            if msg_type == "user_profile":
                allergies = payload.get("allergies", [])
                dislikes = payload.get("dislikes", [])
                restrictions = payload.get("dietary_restrictions", [])
                copilot.load_user_dietary_profile(allergies, dislikes, restrictions)
                logger.info(f"[PROFILE LOADED] User dietary profile loaded: {len(allergies)} allergies, {len(restrictions)} restrictions")
                
            elif msg_type == "select_recipe":
                recipe_id = payload.get("recipe_id")
                copilot.has_explicit_recipe = True

                raw_steps = payload.get("steps") or []
                formatted_steps = []
                for s in raw_steps:
                    s_num = s.get("step_number") or s.get("step") or (len(formatted_steps) + 1)
                    formatted_steps.append({
                        "step_number": s_num,
                        "instruction": s.get("instruction", ""),
                        "timer_seconds": s.get("timer_seconds"),
                        "timer_label": s.get("timer_label"),
                    })

                if recipe_id not in copilot.recipes:
                    latest_all = load_all_recipes()
                    if recipe_id in latest_all:
                        copilot.recipes[recipe_id] = latest_all[recipe_id]
                    else:
                        copilot.recipes[recipe_id] = {
                            "name": payload.get("recipe_name") or recipe_id.replace("_", " ").replace("-", " ").title(),
                            "description": payload.get("description", ""),
                            "steps": formatted_steps,
                            "ingredients": payload.get("ingredients") or [],
                        }

                recipe = copilot.recipes[recipe_id]
                if not recipe.get("steps") and formatted_steps:
                    recipe["steps"] = formatted_steps

                copilot.active_recipe_id = recipe_id
                copilot.current_step_index = 1
                recipe_steps = recipe.get("steps", [])
                rec_name = recipe.get("name", payload.get("recipe_name", recipe_id))
                logger.info(f"[CLIENT UI SYNC] Recipe switched to {recipe_id} ('{rec_name}')")
                asyncio.create_task(copilot.broadcast({
                    "type": "recipe_state",
                    "recipe_id": copilot.active_recipe_id,
                    "recipe_name": rec_name,
                    "current_step": 1,
                    "total_steps": len(recipe_steps),
                    "instruction": recipe_steps[0]["instruction"] if recipe_steps else "",
                }))

                greeting_text = f"Hey Chef! I've got your {rec_name} ready. Let me know when you'd like step 1, or ask for the ingredients!"
                logger.info(f"[AGENT GREETING] Speaking tailored recipe greeting: '{greeting_text}'")
                asyncio.create_task(session.say(
                    greeting_text,
                    allow_interruptions=True,
                    add_to_chat_ctx=True,
                ))
            elif msg_type == "cancel_timer":
                lbl = payload.get("label")
                if lbl and lbl in copilot.active_timers:
                    t = copilot.active_timers.pop(lbl)
                    copilot.active_timer_metadata.pop(lbl, None)
                    t.cancel()
                    asyncio.create_task(copilot.broadcast({
                        "type": "timer_cancelled",
                        "label": lbl,
                    }))
            elif msg_type == "sync_recipe_state":
                # Only sync if a recipe is actually loaded
                if copilot.active_recipe_id is None:
                    logger.info("[DATA SYNC REQUEST] No recipe loaded - skipping sync")
                    return
                
                recipe = copilot.active_recipe
                recipe_steps = recipe.get("steps", [])
                curr_idx = copilot.current_step_index
                curr_instruction = ""
                if recipe_steps and 1 <= curr_idx <= len(recipe_steps):
                    curr_instruction = recipe_steps[curr_idx - 1].get("instruction", "")

                logger.info(f"[DATA SYNC REQUEST] Resending recipe state and timers for {copilot.active_recipe_id} step {curr_idx}")
                asyncio.create_task(copilot.broadcast({
                    "type": "recipe_state",
                    "recipe_id": copilot.active_recipe_id,
                    "recipe_name": recipe.get("name", copilot.active_recipe_id),
                    "current_step": curr_idx,
                    "total_steps": len(recipe_steps),
                    "instruction": curr_instruction,
                }))

                now = time.time()
                for lbl, meta in list(copilot.active_timer_metadata.items()):
                    rem = int(meta["expires_at"] - now)
                    if rem > 0:
                        asyncio.create_task(copilot.broadcast({
                            "type": "timer_started",
                            "label": lbl,
                            "duration_seconds": rem,
                            "expires_at": meta["expires_at"],
                        }))
            elif msg_type == "user_text":
                text = payload.get("text", "").strip()
                if text:
                    logger.info(f"[CLIENT TEXT PROMPT] User requested: '{text}'")
                    session.generate_reply(user_input=text)
        except Exception as e:
            logger.debug(f"[DATA PACKET NOTICE] {e}")

    agent = CookTalkAgent(tools=tools)
    
    # TASK 1 FIX: Wrap session in try/finally to ensure monitor cleanup on ALL exit paths
    try:
        await session.start(room=ctx.room, agent=agent)
        logger.info("CookTalk AgentSession started and ready for speech.")
        
        # TASK 2: Start idle session monitor
        copilot.start_idle_monitor()

        is_benchmark_room = any(ctx.room.name.startswith(p) for p in ("bench-", "diag-", "perf-", "regression-", "smoke-"))
        if not is_benchmark_room:
            async def _greet_chef():
                try:
                    if not ctx.room.remote_participants:
                        logger.info("[AGENT GREETING] Waiting for chef to join room...")
                        await ctx.wait_for_participant()
                    # Wait up to 4.5s for client to join and send select_recipe
                    for _ in range(45):
                        if getattr(copilot, "has_explicit_recipe", False):
                            logger.info("[AGENT GREETING] Recipe already selected by client; skipping generic greeting.")
                            return
                        await asyncio.sleep(0.1)

                    if getattr(copilot, "has_explicit_recipe", False):
                        logger.info("[AGENT GREETING] Recipe already selected by client; skipping generic greeting.")
                        return
                    logger.info("[AGENT GREETING] Speaking initial generic greeting to chef...")
                    session.say(
                        "Hey Chef! I'm CookTalk, your hands-free cooking co-pilot. What are we cooking today?",
                        allow_interruptions=True,
                        add_to_chat_ctx=True,
                    )
                    # DO NOT broadcast recipe_state here - UI should stay in empty state
                    # until user explicitly selects a recipe (via voice or tap)
                    logger.info("[AGENT GREETING] Generic greeting spoken. No recipe loaded - UI will remain in empty state.")
                except Exception as e:
                    logger.warning(f"[AGENT GREETING] Greeting notice: {e}")

            asyncio.create_task(_greet_chef())
    
    finally:
        # TASK 1 FIX: Always stop idle monitor on session exit (explicit or crash)
        logger.info("[SESSION CLEANUP] Stopping idle monitor...")
        copilot.stop_idle_monitor()
        logger.info("[SESSION CLEANUP] Idle monitor stopped. Session ended.")


if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint))
