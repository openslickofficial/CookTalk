"""
CookTalk Phase 2 — LiveKit Streaming Voice Agent
Pipeline:
  - STT: Deepgram (nova-3 streaming)
  - LLM: Groq via OpenAI-compatible plugin (groq/compound-mini, streaming)
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
if RECIPES_FILE.exists():
    with open(RECIPES_FILE, "r", encoding="utf-8") as f:
        RECIPES_DATA = json.load(f)
else:
    RECIPES_DATA = {}

COOKING_CO_PILOT_PROMPT = """You are CookTalk, a voice cooking assistant. Speak 1-2 brief sentences (under 25 words).
Rules:
1. Grounding: Answer recipe questions strictly using your tools and recipes.json.
2. Steps: Call `next_step` for next step, `repeat_step` to repeat, `previous_step` for previous step, `get_current_step` for current step.
3. Recipes: Call `set_active_recipe` with 'scrambled_eggs', 'cacio_e_pepe', or 'ribeye_steak', or `get_recipe_ingredients`.
4. Ingredients & Substitutions: Call `get_ingredient_quantity` or `suggest_substitution`.
5. Timers: Call `start_cooking_timer` for countdown timers.
6. Out of scope: Decline non-cooking questions politely in one sentence.
7. Repeat: When repeat_step is called, recite the instruction verbatim without paraphrasing.
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
    "repeat_step": [
        "Repeating that step for you.",
        "One sec, repeating.",
    ],
    "previous_step": [
        "Going back one step.",
        "Backing up a step.",
    ],
    "set_active_recipe": [
        "Getting that recipe ready.",
        "Pulling up that recipe now.",
    ],
    "start_cooking_timer": [
        "Setting that timer right now.",
        "Starting your timer.",
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
        self.active_recipe_id = "scrambled_eggs"
        self.current_step_index = 1
        self.session: AgentSession | None = None
        self.room: rtc.Room | None = None
        self.active_timers: dict[str, asyncio.Task] = {}

    def set_session(self, session: AgentSession) -> None:
        self.session = session

    def set_room(self, room: rtc.Room) -> None:
        self.room = room

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

    async def broadcast(self, data: dict):
        """Broadcast real-time culinary state to connected WebRTC client."""
        if self.room and self.room.local_participant:
            try:
                payload = json.dumps(data)
                await self.room.local_participant.publish_data(payload, topic="cooktalk")
                logger.info(f"[BROADCAST] Sent data channel event: {data.get('type')}")
            except Exception as e:
                logger.debug(f"[BROADCAST] Data publish notice: {e}")

    @property
    def active_recipe(self) -> dict:
        return self.recipes.get(self.active_recipe_id, self.recipes.get("scrambled_eggs", {}))

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
        async def set_active_recipe(recipe_id: str) -> str:
            """Switch active recipe: scrambled_eggs, cacio_e_pepe, ribeye_steak."""
            clean_id = recipe_id.strip().lower().replace(" ", "_").replace("-", "_")
            if clean_id in copilot.recipes:
                copilot.active_recipe_id = clean_id
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
            return f"Recipe '{recipe_id}' is not in the book. Available recipes are: scrambled eggs, cacio e pepe, and ribeye steak."

        @llm.function_tool
        @track_tool
        async def get_current_step() -> str:
            """Get current recipe instruction."""
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
            """Get quantity of an ingredient in active recipe."""
            recipe = copilot.active_recipe
            target = ingredient_name.strip().lower()
            for ing in recipe.get("ingredients", []):
                if target in ing["name"].lower() or ing["name"].lower() in target:
                    return f"For {recipe['name']}, you need {ing['quantity']} {ing['unit']} of {ing['name']}."
            for r_id, r in copilot.recipes.items():
                for ing in r.get("ingredients", []):
                    if target in ing["name"].lower() or ing["name"].lower() in target:
                        return f"{ing['quantity']} {ing['unit']} in {r['name']}"
            return f"{ingredient_name.title()} is not listed in {recipe['name']}."

        @llm.function_tool
        @track_tool
        async def suggest_substitution(ingredient_name: str) -> str:
            """Suggest substitution for an ingredient in active recipe."""
            recipe = copilot.active_recipe
            target = ingredient_name.strip().lower()
            substitutions = recipe.get("substitutions", {})
            for ing_key, sub_val in substitutions.items():
                if target in ing_key.lower() or ing_key.lower() in target:
                    return f"For {ing_key} in {recipe['name']}: {sub_val}"
            for r_id, r in copilot.recipes.items():
                for ing_key, sub_val in r.get("substitutions", {}).items():
                    if target in ing_key.lower() or ing_key.lower() in target:
                        return f"From {r['name']}: For {ing_key}, you can use {sub_val}"
            return f"No verified culinary substitution is listed for {ingredient_name} in {recipe['name']}."

        @llm.function_tool
        @track_tool
        async def start_cooking_timer(duration_seconds: int, label: str) -> str:
            """Start cooking timer in seconds."""
            secs = max(1, int(duration_seconds))
            clean_label = label.strip() or "cooking step"

            # Broadcast timer start immediately to UI
            await copilot.broadcast({
                "type": "timer_started",
                "label": clean_label,
                "duration_seconds": secs,
                "expires_at": time.time() + secs,
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
                        await copilot.session.say(
                            f"Ding ding! Your timer for {clean_label} is done.",
                            allow_interruptions=True,
                            add_to_chat_ctx=True,
                        )
                except asyncio.CancelledError:
                    logger.info(f"[TIMER CANCELLED] Timer '{clean_label}' was cancelled.")
                except Exception as e:
                    logger.error(f"[TIMER ERROR] Failed to announce timer alert: {e}")
                finally:
                    copilot.active_timers.pop(clean_label, None)

            t = asyncio.create_task(timer_task())
            copilot.active_timers[clean_label] = t
            mins = secs // 60
            rem_secs = secs % 60
            time_str = f"{mins} minute{'s' if mins != 1 else ''}" if rem_secs == 0 else f"{secs} seconds"
            return f"Timer started for {time_str} for {clean_label}. I will tell you when it's done."

        @llm.function_tool
        @track_tool
        async def get_recipe_ingredients(recipe_id: str | None = None) -> str:
            """Get full list of ingredients for a recipe (cacio_e_pepe, scrambled_eggs, ribeye_steak)."""
            target_id = recipe_id.strip().lower().replace(" ", "_") if recipe_id else copilot.active_recipe_id
            recipe = copilot.recipes.get(target_id, copilot.active_recipe)
            ings = recipe.get("ingredients", [])
            if not ings:
                return f"No ingredients found for {recipe.get('name', 'this recipe')}."
            ing_list = ", ".join(f"{i['quantity']} {i['unit']} {i['name']}" for i in ings)
            return f"For {recipe['name']}, you will need: {ing_list}."

        return [
            set_active_recipe,
            get_current_step,
            next_step,
            previous_step,
            repeat_step,
            get_ingredient_quantity,
            get_recipe_ingredients,
            suggest_substitution,
            start_cooking_timer,
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
        new_items.insert(0, llm.ChatMessage(role="user", content="Continue."))

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
                "text": self.last_user_transcript or "Voice question",
                "agent_response": self.last_assistant_response or "",
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

    agent = CookTalkAgent(tools=tools)
    await session.start(room=ctx.room, agent=agent)
    logger.info("CookTalk AgentSession started and ready for speech.")


if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint))
