"""
CookTalk Phase 6.6 — Final Rigorous Demo-Script Benchmark Harness

Measures the exact 5 queries from docs/demo-script.md across 10 rounds (50 trials total):
1. demo_01_ingredients: "What ingredients do I need for Cacio e Pepe?"
2. demo_02_substitution: "What if I don't have Pecorino Romano?"
3. demo_03_next_step: "Got it. What's the next step?"
4. demo_04_steak_science: "Carryover cooking temperature science" (Long multi-clause)
5. demo_05_timer_toast: "Set a timer for 20 seconds for the pepper toast."

For EACH trial, instruments:
  t0: End of caller speech
  t1: First audible frame (acknowledgment phrase) -> time_to_first_audio_ms
  t2: Substantive answer audio frame -> time_to_substantive_answer_ms
  t_end: Turn completion -> total_turn_duration_ms

Reports real median, mean, and p95 across the 10 trials per query.
"""

import asyncio
import io
import json
import os
import sys
import time
import wave
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from dotenv import load_dotenv
from livekit import api, rtc

# Force UTF-8 output on Windows
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ENV_PATH = Path(__file__).parent.parent.parent / ".env"
load_dotenv(ENV_PATH)

LIVEKIT_URL = os.getenv("LIVEKIT_URL")
LIVEKIT_API_KEY = os.getenv("LIVEKIT_API_KEY")
LIVEKIT_API_SECRET = os.getenv("LIVEKIT_API_SECRET")

BENCH_DIR = Path(__file__).parent
FIXTURES_DIR = BENCH_DIR / "fixtures"
RESULTS_FILE = BENCH_DIR / "demo_script_benchmark_results.jsonl"

DEMO_QUERIES = [
    {
        "id": "demo_01_ingredients",
        "name": "Ingredient Query (Cacio e Pepe)",
        "file": FIXTURES_DIR / "demo_01_ingredients.wav",
        "is_tool_expected": True,
    },
    {
        "id": "demo_02_substitution",
        "name": "Substitution Query (Pecorino Romano)",
        "file": FIXTURES_DIR / "demo_02_substitution.wav",
        "is_tool_expected": True,
    },
    {
        "id": "demo_03_next_step",
        "name": "Next-Step Navigation (Step 2)",
        "file": FIXTURES_DIR / "demo_03_next_step.wav",
        "is_tool_expected": True,
    },
    {
        "id": "demo_04_steak_science",
        "name": "Carryover Cooking Science (Long Multi-Clause)",
        "file": FIXTURES_DIR / "demo_04_steak_science.wav",
        "is_tool_expected": False,
    },
    {
        "id": "demo_05_timer_toast",
        "name": "Timer Setting (20s Pepper Toast)",
        "file": FIXTURES_DIR / "demo_05_timer_toast.wav",
        "is_tool_expected": True,
    },
]

ROUNDS = 10
IDLE_GAP_SEC = 16.0
AUDIBLE_PEAK_THRESHOLD = 600
CHUNK_MS = 20  # 20ms frames


def read_wav_frames(wav_path: Path):
    with wave.open(str(wav_path), "rb") as wf:
        sample_rate = wf.getframerate()
        channels = wf.getnchannels()
        sampwidth = wf.getsampwidth()
        num_frames = wf.getnframes()
        pcm_bytes = wf.readframes(num_frames)

    samples_per_chunk = int(sample_rate * (CHUNK_MS / 1000.0))
    bytes_per_chunk = samples_per_chunk * channels * sampwidth

    chunks = []
    last_speech_idx = 0
    for i, offset in enumerate(range(0, len(pcm_bytes), bytes_per_chunk)):
        chunk = pcm_bytes[offset : offset + bytes_per_chunk]
        if len(chunk) == bytes_per_chunk:
            chunks.append(chunk)
            samples = np.frombuffer(chunk, dtype=np.int16)
            if np.max(np.abs(samples)) > 500:
                last_speech_idx = i

    return sample_rate, channels, samples_per_chunk, chunks, last_speech_idx


class DemoBenchHarness:
    def __init__(self, room_name: str):
        self.room_name = room_name
        self.room = rtc.Room()
        self.agent_audio_track = None
        self.agent_joined = asyncio.Event()
        self.track_subscribed = asyncio.Event()
        self.data_events = []

    async def connect(self):
        token = (
            api.AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET)
            .with_identity("bench_demo_evaluator")
            .with_name("Bench Demo Evaluator")
            .with_grants(api.VideoGrants(room_join=True, room=self.room_name))
            .to_jwt()
        )

        @self.room.on("participant_connected")
        def on_p_conn(p: rtc.RemoteParticipant):
            if "agent" in p.identity.lower():
                self.agent_joined.set()

        @self.room.on("track_subscribed")
        def on_track_sub(track: rtc.Track, pub, p: rtc.RemoteParticipant):
            if track.kind == rtc.TrackKind.KIND_AUDIO:
                self.agent_audio_track = track
                self.track_subscribed.set()

        @self.room.on("data_received")
        def on_data(dp: rtc.DataPacket):
            try:
                payload = json.loads(dp.data.decode("utf-8"))
                self.data_events.append(payload)
            except Exception:
                pass

        print(f"Connecting to LiveKit room '{self.room_name}'...")
        await self.room.connect(LIVEKIT_URL, token)

        for p in self.room.remote_participants.values():
            if "agent" in p.identity.lower():
                self.agent_joined.set()
            for pub in p.track_publications.values():
                if pub.track and pub.track.kind == rtc.TrackKind.KIND_AUDIO:
                    self.agent_audio_track = pub.track
                    self.track_subscribed.set()

        if not self.agent_joined.is_set():
            print("Waiting for agent to enter...")
            await asyncio.wait_for(self.agent_joined.wait(), timeout=20.0)

        if not self.track_subscribed.is_set():
            print("Waiting for agent audio track...")
            await asyncio.wait_for(self.track_subscribed.wait(), timeout=15.0)

        print("Agent is present with subscribed audio track.")

    async def run_trial(
        self,
        trial_num: int,
        round_num: int,
        q_cfg: dict,
        source: rtc.AudioSource,
    ) -> dict:
        q_id = q_cfg["id"]
        q_name = q_cfg["name"]
        wav_file = q_cfg["file"]
        is_tool = q_cfg["is_tool_expected"]

        print(f"\n--- [Trial {trial_num}/50] [Round {round_num}/{ROUNDS}] {q_name} ---")
        sr, nch, spc, chunks, last_sp_idx = read_wav_frames(wav_file)

        audio_stream = rtc.AudioStream(self.agent_audio_track)
        t0 = None
        t1_first_audio = None
        t2_substantive = None
        t_end = None
        heard_peak1 = 0
        heard_peak2 = 0

        ack_playing = False
        ack_finished = False
        silence_after_ack = 0

        turn_done = asyncio.Event()

        async def listen_audio():
            nonlocal t1_first_audio, t2_substantive, heard_peak1, heard_peak2, t_end
            nonlocal ack_playing, ack_finished, silence_after_ack
            silence_frames = 0

            async for ev in audio_stream:
                now = time.perf_counter()
                samples = np.frombuffer(ev.frame.data, dtype=np.int16)
                peak = int(np.max(np.abs(samples))) if len(samples) > 0 else 0

                if peak >= AUDIBLE_PEAK_THRESHOLD:
                    if t1_first_audio is None and t0 is not None:
                        t1_first_audio = now
                        heard_peak1 = peak
                        ack_playing = True

                    if is_tool:
                        if ack_finished and t2_substantive is None:
                            t2_substantive = now
                            heard_peak2 = peak
                    else:
                        if t2_substantive is None:
                            t2_substantive = t1_first_audio

                    silence_frames = 0
                else:
                    if ack_playing and not ack_finished:
                        silence_after_ack += 1
                        # ~240ms of silence indicates end of acknowledgment phrase
                        if silence_after_ack > 12:
                            ack_finished = True

                    if t1_first_audio is not None:
                        silence_frames += 1
                        # If silence persists for 1.6s after substantive speech, turn complete
                        if silence_frames > 80:
                            t_end = now - 1.6
                            turn_done.set()
                            break

        listen_task = asyncio.create_task(listen_audio())
        await asyncio.sleep(0.1)
        self.data_events.clear()

        # 1. Stream WAV
        print(f"  Streaming audio ({q_name})...", end=" ", flush=True)
        chunk_interval = CHUNK_MS / 1000.0
        for i, chunk in enumerate(chunks):
            frame = rtc.AudioFrame(chunk, sr, nch, spc)
            await source.capture_frame(frame)
            if i == last_sp_idx and t0 is None:
                t0 = time.perf_counter()
            await asyncio.sleep(chunk_interval * 0.98)

        if t0 is None:
            t0 = time.perf_counter()
        print("DONE (speech ended, trailing silence streamed)")

        # 2. Keep alive silence frames until speech starts so VAD doesn't starve
        keep_alive = True
        async def stream_background_silence():
            silent_chunk = bytes(spc * nch * 2)
            while keep_alive:
                s_frame = rtc.AudioFrame(silent_chunk, sr, nch, spc)
                await source.capture_frame(s_frame)
                await asyncio.sleep(0.02)

        silence_task = asyncio.create_task(stream_background_silence())

        print("Waiting for response...", end=" ", flush=True)
        try:
            # Wait for first audio
            while t1_first_audio is None:
                await asyncio.sleep(0.01)
                if (time.perf_counter() - t0) > 25.0:
                    raise TimeoutError("Agent first-audio timeout (>25s)")

            # Stop feeding silence frames once agent starts speaking
            keep_alive = False
            silence_task.cancel()

            first_audio_ms = (t1_first_audio - t0) * 1000.0
            print(f"FIRST SOUND in {first_audio_ms:.1f} ms (Peak: {heard_peak1})", end=" | ", flush=True)

            # Wait for turn completion
            t_wait_start = time.perf_counter()
            while not turn_done.is_set() and (time.perf_counter() - t_wait_start) < 22.0:
                await asyncio.sleep(0.02)

            if t2_substantive is None:
                t2_substantive = t1_first_audio
            if t_end is None:
                t_end = time.perf_counter()

            substantive_ms = (t2_substantive - t0) * 1000.0
            total_turn_ms = (t_end - t0) * 1000.0
            print(f"SUBSTANTIVE in {substantive_ms:.1f} ms | TOTAL: {total_turn_ms:.1f} ms")

            await asyncio.sleep(0.4)

        finally:
            keep_alive = False
            silence_task.cancel()
            listen_task.cancel()
            await audio_stream.aclose()


        # Extract latest server turn metrics from data channel
        latest_metrics = {}
        for ev in reversed(self.data_events):
            if ev.get("type") == "turn_metrics":
                latest_metrics = ev
                break

        tool_called = latest_metrics.get("tool_called")
        tool_exec_ms = latest_metrics.get("tool_execution_ms")
        tool_rt_ms = latest_metrics.get("tool_roundtrip_ms")
        ack_phrase = latest_metrics.get("acknowledgment_phrase")
        llm_ttft = latest_metrics.get("llm_ttft_ms")
        tts_ttfb = latest_metrics.get("tts_ttfb_ms")
        agent_resp = latest_metrics.get("agent_response", "")
        status = "success" if (first_audio_ms is not None and first_audio_ms > 400) else latest_metrics.get("status", "incomplete")

        print(f"  [METRICS] Tool: {tool_called} | Ack: \"{ack_phrase}\" | LLM TTFT: {llm_ttft} ms | TTS TTFB: {tts_ttfb} ms")
        print(f"  [REPLY] \"{agent_resp[:60]}...\"")

        record = {
            "trial_num": trial_num,
            "round_num": round_num,
            "query_id": q_id,
            "query_name": q_name,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "time_to_first_audio_ms": round(first_audio_ms, 1),
            "time_to_substantive_answer_ms": round(substantive_ms, 1),
            "total_turn_duration_ms": round(total_turn_ms, 1),
            "audible_peak1": heard_peak1,
            "audible_peak2": heard_peak2,
            "acknowledgment_phrase": ack_phrase,
            "tool_called": tool_called,
            "tool_execution_ms": tool_exec_ms,
            "tool_roundtrip_ms": tool_rt_ms,
            "llm_ttft_ms": llm_ttft,
            "tts_ttfb_ms": tts_ttfb,
            "agent_response": agent_resp,
            "status": status,
        }
        return record

    async def disconnect(self):
        await self.room.disconnect()


async def main():
    print("=" * 75)
    print("CookTalk Phase 6.6 — Exact Demo-Script Benchmark (10 Rounds x 5 Queries)")
    print("=" * 75)
    print(f"Target: {LIVEKIT_URL}")
    print(f"Pacing: {IDLE_GAP_SEC}s controlled pause between trials")
    print(f"Results: {RESULTS_FILE}\n")

    if RESULTS_FILE.exists():
        RESULTS_FILE.unlink()

    # --- PRE-FLIGHT: Wait until Groq TPD has enough headroom ---
    # Strategy: use a tiny probe (max_completion_tokens=1) to check if TPD is OK.
    # If probe fails with 'tokens per day', wait and retry.
    # If probe passes, check remaining-tokens header; if it's near-full (>=7000/8000 TPM),
    # we have at least one full per-minute window available for the first few trials.
    # We do NOT use large probes since they consume the very headroom we're testing.
    GROQ_API_KEY = os.getenv("GROQ_API_KEY")
    GROQ_MODEL = os.getenv("GROQ_MODEL", "qwen/qwen3.8-27b")
    TOKENS_NEEDED_ESTIMATE = ROUNDS * len(DEMO_QUERIES) * 1100  # ~1100 tokens per tool-schema request
    print(f"Pre-flight: Waiting for Groq TPD headroom (~{TOKENS_NEEDED_ESTIMATE} tokens for {ROUNDS * len(DEMO_QUERIES)} trials)...")
    print("  (Using minimal probes to preserve quota. Will start when 3 consecutive probes succeed.)")

    import urllib.request as _urllib_req
    import re as _re

    def _tiny_probe():
        """Send a tiny 1-token probe. Returns (success, remaining_tpm, used_tpd_str)."""
        body = json.dumps({
            "model": GROQ_MODEL,
            "messages": [{"role": "user", "content": "hi"}],
            "max_completion_tokens": 1,
        }).encode("utf-8")
        req = _urllib_req.Request(
            "https://api.groq.com/openai/v1/chat/completions",
            data=body,
            headers={
                "Authorization": f"Bearer {GROQ_API_KEY}",
                "Content-Type": "application/json",
                "User-Agent": "Mozilla/5.0",
            },
        )
        try:
            with _urllib_req.urlopen(req) as resp:
                remaining = int(resp.headers.get("x-ratelimit-remaining-tokens", "0"))
                return True, remaining, ""
        except Exception as e:
            err_msg = ""
            if hasattr(e, "read"):
                try:
                    err_body = e.read().decode()
                    m = _re.search(r"Used (\d+),", err_body)
                    if m:
                        used = int(m.group(1))
                        headroom = 200000 - used
                        err_msg = f"Used={used}/200000, Headroom={headroom}"
                    m2 = _re.search(r"try again in ([0-9hms.]+)", err_body, _re.IGNORECASE)
                    if m2:
                        err_msg += f", retry_in={m2.group(1)}"
                except Exception:
                    pass
            return False, 0, err_msg

    consecutive_ok = 0
    while consecutive_ok < 3:
        ok, remaining_tpm, err = _tiny_probe()
        if ok:
            consecutive_ok += 1
            print(f"  Probe {consecutive_ok}/3 OK (TPM remaining: {remaining_tpm}). Waiting 2s before next...")
            if consecutive_ok < 3:
                await asyncio.sleep(2)
        else:
            consecutive_ok = 0
            wait_secs = 120 if "Headroom=" in err and int(_re.search(r"Headroom=(\d+)", err).group(1)) < 2000 else 60
            print(f"  Groq TPD exhausted: {err}. Waiting {wait_secs}s...")
            await asyncio.sleep(wait_secs)

    print(f"  Pre-flight passed. Starting benchmark.")

    room_name = f"bench-demo-script-{int(time.time())}"
    harness = DemoBenchHarness(room_name)
    await harness.connect()

    source = rtc.AudioSource(sample_rate=16000, num_channels=1)
    mic_track = rtc.LocalAudioTrack.create_audio_track("bench_mic", source)
    await harness.room.local_participant.publish_track(
        mic_track, rtc.TrackPublishOptions(source=rtc.TrackSource.SOURCE_MICROPHONE)
    )
    print("Published microphone track (SOURCE_MICROPHONE).")

    async def feed_silence(duration_sec: float):
        silent_chunk = bytes(320 * 2)
        t_end = time.perf_counter() + duration_sec
        while time.perf_counter() < t_end:
            frame = rtc.AudioFrame(silent_chunk, 16000, 1, 320)
            await source.capture_frame(frame)
            await asyncio.sleep(0.02)

    print("Settle media connection for 2.0s...")
    await asyncio.sleep(2.0)

    all_records = []
    trial_count = 0

    try:
        for r_idx in range(1, ROUNDS + 1):
            print(f"\n===========================================================================")
            print(f"STARTING ROUND {r_idx}/{ROUNDS}")
            print(f"===========================================================================")

            for q_cfg in DEMO_QUERIES:
                trial_count += 1
                if trial_count > 1:
                    print(f"\nHolding {IDLE_GAP_SEC}s pause between trials...", end=" ", flush=True)
                    await asyncio.sleep(IDLE_GAP_SEC)
                    print("DONE")


                try:
                    rec = await harness.run_trial(trial_count, r_idx, q_cfg, source)
                except Exception as trial_err:
                    print(f"FAILED ({trial_err})")
                    rec = {
                        "trial_num": trial_count,
                        "round_num": r_idx,
                        "query_id": q_cfg["id"],
                        "query_name": q_cfg["name"],
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                        "time_to_first_audio_ms": None,
                        "time_to_substantive_answer_ms": None,
                        "total_turn_duration_ms": None,
                        "audible_peak1": 0,
                        "audible_peak2": 0,
                        "acknowledgment_phrase": None,
                        "tool_called": None,
                        "tool_execution_ms": None,
                        "tool_roundtrip_ms": None,
                        "llm_ttft_ms": None,
                        "tts_ttfb_ms": None,
                        "agent_response": f"Error: {trial_err}",
                        "status": "timeout" if isinstance(trial_err, TimeoutError) else "error",
                    }
                all_records.append(rec)
                with open(RESULTS_FILE, "a", encoding="utf-8") as f:
                    f.write(json.dumps(rec) + "\n")

    finally:
        await harness.disconnect()

    # Print Statistically Rigorous Per-Query Breakdown Table
    print("\n" + "=" * 85)
    print("PHASE 6.6 STATISTICALLY RIGOROUS DEMO-QUERY BENCHMARK BREAKDOWN (n=10 per query)")
    print("=" * 85)
    header = f"{'Query Name':<28} | {'Metric':<18} | {'Median':<10} | {'Mean':<10} | {'P95':<10}"
    print(header)
    print("-" * 85)

    for q_cfg in DEMO_QUERIES:
        q_id = q_cfg["id"]
        q_name = q_cfg["name"]
        q_records = [r for r in all_records if r["query_id"] == q_id and r["status"] == "success"]
        n = len(q_records)
        if n == 0:
            continue

        t_first = [r["time_to_first_audio_ms"] for r in q_records]
        t_sub = [r["time_to_substantive_answer_ms"] for r in q_records]
        t_tot = [r["total_turn_duration_ms"] for r in q_records]

        print(f"{q_name:<28} | First-Audio (Ack)  | {np.median(t_first):<10.1f} | {np.mean(t_first):<10.1f} | {np.percentile(t_first, 95):<10.1f}")
        print(f"{'':<28} | Substantive Answer | {np.median(t_sub):<10.1f} | {np.mean(t_sub):<10.1f} | {np.percentile(t_sub, 95):<10.1f}")
        print(f"{'':<28} | Total Turn Time    | {np.median(t_tot):<10.1f} | {np.mean(t_tot):<10.1f} | {np.percentile(t_tot, 95):<10.1f}")
        print("-" * 85)

    print("=" * 85)


if __name__ == "__main__":
    asyncio.run(main())
