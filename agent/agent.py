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

from livekit.agents import (
    Agent,
    AgentSession,
    ConversationItemAddedEvent,
    JobContext,
    MetricsCollectedEvent,
    UserInputTranscribedEvent,
    WorkerOptions,
    cli,
)
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

SYSTEM_PROMPT = (
    "You are a helpful voice assistant. Keep answers to 1-2 short sentences."
)

RIME_MODEL = "coda"
RIME_SPEAKER = "astra"
GROQ_MODEL = "qwen/qwen3.8-27b"
DEEPGRAM_MODEL = "nova-3"


class TurnMetricsManager:
    """Manages turn correlation and metrics logging for streaming results."""

    def __init__(self, results_file: Path):
        self.results_file = results_file
        self.turns = {}  # speech_id -> dict of metrics
        self.latest_speech_id = None
        self.last_user_transcript = ""

    def get_or_create(self, speech_id: str | None) -> dict:
        sid = speech_id or self.latest_speech_id or "turn_default"
        if sid not in self.turns:
            self.turns[sid] = {
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "speech_id": sid,
                "text": self.last_user_transcript or "Voice question",
                "agent_response": "",
                "eou_delay_ms": None,
                "llm_ttft_ms": None,
                "tts_ttfb_ms": None,
                "tts_audio_duration_ms": None,
                "tts_duration_ms": None,
                "latency_ms": None,
                "tts_provider": "rime",
                "tts_model": RIME_MODEL,
                "tts_speaker": RIME_SPEAKER,
                "streaming": True,
                "protocol": "websocket_ws3",
            }
        self.latest_speech_id = sid
        return self.turns[sid]

    def record_user_transcript(self, transcript: str):
        if transcript.strip():
            self.last_user_transcript = transcript.strip()
            turn = self.get_or_create(self.latest_speech_id)
            turn["text"] = self.last_user_transcript

    def record_eou(self, metrics: EOUMetrics):
        turn = self.get_or_create(metrics.speech_id)
        if metrics.end_of_utterance_delay is not None:
            turn["eou_delay_ms"] = round(metrics.end_of_utterance_delay * 1000, 1)
        logger.info(f"[VAD/EOU] End of utterance delay: {turn['eou_delay_ms']} ms")

    def record_llm(self, metrics: LLMMetrics):
        turn = self.get_or_create(metrics.speech_id)
        if metrics.ttft is not None:
            turn["llm_ttft_ms"] = round(metrics.ttft * 1000, 1)
        tps = metrics.tokens_per_second if hasattr(metrics, "tokens_per_second") and metrics.tokens_per_second else 0.0
        logger.info(
            f"[LLM Groq {GROQ_MODEL}] TTFT: {turn['llm_ttft_ms']} ms | Tokens/sec: {tps:.1f}"
        )

    def record_tts(self, metrics: TTSMetrics):
        turn = self.get_or_create(metrics.speech_id)
        if metrics.ttfb is not None:
            turn["tts_ttfb_ms"] = round(metrics.ttfb * 1000, 1)
        if metrics.audio_duration is not None:
            turn["tts_audio_duration_ms"] = round(metrics.audio_duration * 1000, 1)
        if metrics.duration is not None:
            turn["tts_duration_ms"] = round(metrics.duration * 1000, 1)

        # Perceived End-to-End Latency:
        eou = turn.get("eou_delay_ms") or 0.0
        ttft = turn.get("llm_ttft_ms") or 0.0
        ttfb = turn.get("tts_ttfb_ms") or 0.0
        e2e_ms = round(eou + ttft + ttfb, 1) if (ttft or ttfb) else ttfb
        turn["latency_ms"] = e2e_ms

        # Active provider observability rule:
        logger.info(
            f"[ACTIVE TTS PROVIDER: RIME] Model: {RIME_MODEL} | Voice: {RIME_SPEAKER} | Protocol: WebSocket /ws3"
        )
        logger.info(
            f"[STREAMING TURN MEASURED] E2E Perceived: {e2e_ms} ms (EOU: {eou} ms | LLM TTFT: {ttft} ms | Rime TTFB: {ttfb} ms)"
        )

        try:
            with open(self.results_file, "a", encoding="utf-8") as f:
                f.write(json.dumps(turn) + "\n")
            logger.info(f"[METRICS] Recorded turn to {self.results_file.name}")
        except Exception as e:
            logger.error(f"Error writing to JSONL: {e}")

        if metrics.speech_id and metrics.speech_id in self.turns:
            del self.turns[metrics.speech_id]


metrics_manager = TurnMetricsManager(STREAMING_RESULTS_FILE)


class CookTalkAgent(Agent):
    def __init__(self):
        super().__init__(instructions=SYSTEM_PROMPT)

    async def on_enter(self) -> None:
        logger.info("[AGENT] CookTalk Agent is active and listening for questions in the playground.")


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

    # STT: Deepgram streaming
    stt_plugin = deepgram.STT(
        model=DEEPGRAM_MODEL,
        language="en-US",
        api_key=deepgram_key,
    )

    # LLM: Groq via OpenAI-compatible plugin with streaming
    llm_plugin = openai.LLM(
        model=GROQ_MODEL,
        base_url="https://api.groq.com/openai/v1",
        api_key=groq_key,
        max_completion_tokens=80,
    )

    # TTS: Rime official plugin with true WebSocket streaming (/ws3)
    tts_plugin = rime.TTS(
        model=RIME_MODEL,
        speaker=RIME_SPEAKER,
        use_websocket=True,
        api_key=rime_key,
    )

    # VAD: Silero local neural model
    vad_plugin = silero.VAD.load()

    logger.info(
        f"[PIPELINE INITIALIZED] STT=Deepgram({DEEPGRAM_MODEL}) | LLM=Groq({GROQ_MODEL}) | TTS=Rime({RIME_MODEL}/{RIME_SPEAKER} via WebSocket /ws3)"
    )

    session = AgentSession(
        vad=vad_plugin,
        stt=stt_plugin,
        llm=llm_plugin,
        tts=tts_plugin,
    )

    @session.on("user_input_transcribed")
    def on_transcription(ev: UserInputTranscribedEvent):
        if ev.is_final:
            metrics_manager.record_user_transcript(ev.transcript)

    @session.on("conversation_item_added")
    def on_conversation_item(ev: ConversationItemAddedEvent):
        # Keep sliding history window so LLM context stays fast and responsive
        try:
            if len(session.history.items) > 4:
                session.history.truncate(max_items=4)
        except Exception:
            pass

        role = getattr(ev.item, "role", "")
        content = getattr(ev.item, "content", "")
        if isinstance(content, list):
            content = " ".join(str(c) for c in content)
        if role == "user":
            metrics_manager.record_user_transcript(str(content))
        elif role == "assistant":
            sid = metrics_manager.latest_speech_id or "turn_default"
            if sid in metrics_manager.turns:
                metrics_manager.turns[sid]["agent_response"] = str(content)

    @session.on("metrics_collected")
    def on_metrics(ev: MetricsCollectedEvent):
        m = ev.metrics
        if isinstance(m, EOUMetrics):
            metrics_manager.record_eou(m)
        elif isinstance(m, LLMMetrics):
            metrics_manager.record_llm(m)
        elif isinstance(m, TTSMetrics):
            metrics_manager.record_tts(m)

    agent = CookTalkAgent()
    await session.start(room=ctx.room, agent=agent)
    logger.info("CookTalk AgentSession started and ready for speech.")


if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint))
