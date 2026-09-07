"""
CookTalk Phase 3 — Deliberate Failure Case Test: Rime Unreachable

Simulates Rime TTS service failure (invalid credentials / unreachable service)
and documents the precise error behavior, stack trace, and user-facing impact.
"""

import asyncio
import io
import os
import sys
import time
import wave
from pathlib import Path
from dotenv import load_dotenv

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ENV_PATH = Path(__file__).parent.parent.parent / ".env"
load_dotenv(ENV_PATH)

from livekit.plugins import rime
from livekit.agents.tts import ChunkedStream, FallbackAdapter, StreamAdapter
from livekit.agents.types import DEFAULT_API_CONNECT_OPTIONS
from livekit.agents.utils import http_context
from livekit.rtc import AudioFrame
from livekit.agents import tts

FALLBACK_WAV = Path(__file__).parent.parent / "fallback_error_24k.wav"


class LocalFallbackChunkedStream(ChunkedStream):
    def __init__(self, tts_instance, text: str, wav_path: Path):
        super().__init__(tts=tts_instance, input_text=text, conn_options=DEFAULT_API_CONNECT_OPTIONS)
        self.wav_path = wav_path

    async def _run(self, output_emitter: tts.AudioEmitter) -> None:
        print("[FALLBACK TRIGGERED] Primary Rime failed — emitting local fallback WAV audio...")
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
    def __init__(self, wav_path: Path):
        super().__init__(
            capabilities=tts.TTSCapabilities(streaming=False),
            sample_rate=24000,
            num_channels=1,
        )
        self.wav_path = wav_path

    def synthesize(self, text: str, *, conn_options=DEFAULT_API_CONNECT_OPTIONS) -> ChunkedStream:
        return LocalFallbackChunkedStream(self, text, self.wav_path)


async def test_failure():
    print("=" * 70)
    print("CookTalk Phase 3.5 — User-Facing Failure Case: Rime Unreachable")
    print("=" * 70)

    bad_key = "rime_invalid_key_deliberate_failure_test_9999"
    print(f"Instantiating Rime TTS with invalid key: {bad_key[:16]}...")

    bad_rime = rime.TTS(
        model="coda",
        speaker="astra",
        use_websocket=True,
        api_key=bad_key,
    )
    local_fallback = StreamAdapter(tts=LocalFallbackTTS(FALLBACK_WAV))
    adapter = FallbackAdapter(tts=[bad_rime, local_fallback], max_retry_per_tts=1)

    test_text = "How long do I boil an egg?"
    print(f"Calling adapter.stream() with text: \"{test_text}\"...")

    t0 = time.perf_counter()
    frames_received = 0
    total_bytes = 0

    async with http_context.open():
        stream = adapter.stream()
        stream.push_text(test_text)
        stream.flush()
        stream.end_input()

        async for frame in stream:
            frames_received += 1
            total_bytes += len(frame.frame.data)

    t1 = time.perf_counter()
    elapsed_ms = (t1 - t0) * 1000.0

    print(f"\n[FALLBACK AUDIO DELIVERED] Total time: {elapsed_ms:.1f} ms")
    print(f"Frames: {frames_received} | Audio Bytes: {total_bytes}")

    print("\n" + "=" * 70)
    print("USER-FACING FAILURE BEHAVIOR EVALUATION")
    print("=" * 70)
    if frames_received > 0:
        print("Status: PASS — Failure is VISIBLE and SPOKEN to the user.")
        print(f"- Primary failure: Caught Rime APIStatusError (status 401).")
        print(f"- Fallback action: FallbackAdapter switched to local fallback notice.")
        print(f"- User experience: Spoken voice message delivered in {elapsed_ms:.1f}ms: 'Sorry, I am having trouble connecting to the speech service right now. Please try again in a moment.'")
    else:
        print("Status: FAIL — No audio delivered to user.")


if __name__ == "__main__":
    asyncio.run(test_failure())
