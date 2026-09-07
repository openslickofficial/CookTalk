"""
CookTalk Phase 6.5 — Controlled Tool-Overhead Benchmark Harness

Quantifies the exact latency breakdown between Plain Q&A turns (1 LLM stream)
and Tool-Assisted turns (LLM Call 1 -> Python Tool Execution -> LLM Call 2).

Runs 6 alternating trials (3 Plain Q&A vs 3 Tool Calls) with a controlled 20s idle pause.
Measures:
  t0: End of user speech in synthetic WAV
  t1: First audible agent frame from WebRTC audio track
  Server telemetry: tool_execution_ms, tool_roundtrip_ms, llm_ttft_ms, rime_ttfb_ms
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
RESULTS_FILE = BENCH_DIR / "tool_overhead_results.jsonl"

TEST_TRIALS = [
    {
        "trial_num": 1,
        "type": "plain_qa",
        "name": "Plain Q&A 1 (Egg)",
        "file": FIXTURES_DIR / "short_01_egg.wav",
        "expected_tool": None,
    },
    {
        "trial_num": 2,
        "type": "tool_call",
        "name": "Tool Call 1 (Next Step)",
        "file": FIXTURES_DIR / "acc_02_next_step.wav",
        "expected_tool": "next_step",
    },
    {
        "trial_num": 3,
        "type": "plain_qa",
        "name": "Plain Q&A 2 (Chicken)",
        "file": FIXTURES_DIR / "short_02_chicken.wav",
        "expected_tool": None,
    },
    {
        "trial_num": 4,
        "type": "tool_call",
        "name": "Tool Call 2 (Ingredient Quantity)",
        "file": FIXTURES_DIR / "acc_04_ingredient_qty.wav",
        "expected_tool": "get_ingredient_quantity",
    },
    {
        "trial_num": 5,
        "type": "plain_qa",
        "name": "Plain Q&A 3 (Pasta)",
        "file": FIXTURES_DIR / "short_03_pasta.wav",
        "expected_tool": None,
    },
    {
        "trial_num": 6,
        "type": "tool_call",
        "name": "Tool Call 3 (Substitution)",
        "file": FIXTURES_DIR / "acc_05_substitution.wav",
        "expected_tool": "suggest_substitution",
    },
]

AUDIBLE_PEAK_THRESHOLD = 600
CHUNK_MS = 20  # 20ms frames
IDLE_GAP_SEC = 20.0


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


async def main():
    print("=" * 70)
    print("CookTalk Phase 6.5 — Controlled Tool-Overhead Benchmark")
    print("=" * 70)
    print(f"Target: {LIVEKIT_URL}")
    print(f"Pacing: {IDLE_GAP_SEC}s controlled pause between trials")
    print(f"Results: {RESULTS_FILE}\n")

    if RESULTS_FILE.exists():
        RESULTS_FILE.unlink()

    room_name = f"bench-tool-overhead-{int(time.time())}"
    token = (
        api.AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET)
        .with_identity("bench_tool_tester")
        .with_name("Bench Tool Tester")
        .with_grants(api.VideoGrants(room_join=True, room=room_name))
        .to_jwt()
    )

    room = rtc.Room()
    agent_joined = asyncio.Event()
    track_subscribed = asyncio.Event()
    agent_audio_track = None
    data_events = []

    @room.on("participant_connected")
    def on_p_conn(p: rtc.RemoteParticipant):
        if "agent" in p.identity.lower():
            agent_joined.set()

    @room.on("track_subscribed")
    def on_track_sub(track: rtc.Track, pub, p: rtc.RemoteParticipant):
        nonlocal agent_audio_track
        if track.kind == rtc.TrackKind.KIND_AUDIO:
            agent_audio_track = track
            track_subscribed.set()

    @room.on("data_received")
    def on_data(dp: rtc.DataPacket):
        try:
            payload = json.loads(dp.data.decode("utf-8"))
            data_events.append(payload)
        except Exception:
            pass

    print(f"Connecting to LiveKit room '{room_name}'...")
    await room.connect(LIVEKIT_URL, token)

    for p in room.remote_participants.values():
        if "agent" in p.identity.lower():
            agent_joined.set()
        for pub in p.track_publications.values():
            if pub.track and pub.track.kind == rtc.TrackKind.KIND_AUDIO:
                agent_audio_track = pub.track
                track_subscribed.set()

    if not agent_joined.is_set():
        print("Waiting for agent to enter...")
        await asyncio.wait_for(agent_joined.wait(), timeout=20.0)

    if not track_subscribed.is_set():
        print("Waiting for agent audio track...")
        await asyncio.wait_for(track_subscribed.wait(), timeout=15.0)

    print("Agent is present with subscribed audio track.")

    source = rtc.AudioSource(sample_rate=16000, num_channels=1)
    mic_track = rtc.LocalAudioTrack.create_audio_track("bench_mic", source)
    await room.local_participant.publish_track(
        mic_track, rtc.TrackPublishOptions(source=rtc.TrackSource.SOURCE_MICROPHONE)
    )
    print("Published microphone track (SOURCE_MICROPHONE).")

    async def feed_silence(duration_sec: float):
        silent_chunk = bytes(320 * 2)  # 20ms @ 16kHz mono
        t_end = time.perf_counter() + duration_sec
        while time.perf_counter() < t_end:
            frame = rtc.AudioFrame(silent_chunk, 16000, 1, 320)
            await source.capture_frame(frame)
            await asyncio.sleep(0.02)

    print("Settle media connection and VAD with 3.0s silence feed...")
    await feed_silence(3.0)

    results = []
    try:
        for idx, trial_cfg in enumerate(TEST_TRIALS):
            trial_num = trial_cfg["trial_num"]
            trial_type = trial_cfg["type"]
            name = trial_cfg["name"]
            wav_file = trial_cfg["file"]

            if idx > 0:
                print(f"\nHolding idle for {IDLE_GAP_SEC}s pause (feeding background silence)...", end=" ", flush=True)
                await feed_silence(IDLE_GAP_SEC)
                print("DONE")

            print(f"\n--- [Trial {trial_num}/6] [{trial_type.upper()}] {name} ---")
            sr, nch, spc, chunks, last_sp_idx = read_wav_frames(wav_file)

            audio_stream = rtc.AudioStream(agent_audio_track)
            t0 = None
            t1 = None
            heard_peak = 0
            turn_done = asyncio.Event()

            async def listen_audio():
                nonlocal t1, heard_peak
                silence_frames = 0
                async for ev in audio_stream:
                    samples = np.frombuffer(ev.frame.data, dtype=np.int16)
                    peak = int(np.max(np.abs(samples))) if len(samples) > 0 else 0
                    if peak >= AUDIBLE_PEAK_THRESHOLD:
                        if t1 is None and t0 is not None:
                            t1 = time.perf_counter()
                            heard_peak = peak
                        silence_frames = 0
                    else:
                        if t1 is not None:
                            silence_frames += 1
                            if silence_frames > 60:
                                turn_done.set()
                                break

            listen_task = asyncio.create_task(listen_audio())
            await asyncio.sleep(0.1)
            data_events.clear()

            print(f"  Streaming audio ({name})...", end=" ", flush=True)
            chunk_interval = 0.02
            for i, chunk in enumerate(chunks):
                frame = rtc.AudioFrame(chunk, sr, nch, spc)
                await source.capture_frame(frame)
                if i == last_sp_idx and t0 is None:
                    t0 = time.perf_counter()
                await asyncio.sleep(chunk_interval * 0.98)

            if t0 is None:
                t0 = time.perf_counter()

            print("Waiting for agent response...", end=" ", flush=True)
            silent_chunk = bytes(spc * nch * 2)
            try:
                while t1 is None:
                    s_frame = rtc.AudioFrame(silent_chunk, sr, nch, spc)
                    await source.capture_frame(s_frame)
                    await asyncio.sleep(0.02)
                    if (time.perf_counter() - t0) > 16.0:
                        raise TimeoutError("Agent response timeout (>16s)")

                client_latency_ms = (t1 - t0) * 1000.0
                print(f"RECEIVED! Peak={heard_peak}, Client Latency={client_latency_ms:.1f} ms")

                # Feed silence until turn completes
                t_turn_wait = time.perf_counter()
                while not turn_done.is_set() and (time.perf_counter() - t_turn_wait) < 12.0:
                    s_frame = rtc.AudioFrame(silent_chunk, sr, nch, spc)
                    await source.capture_frame(s_frame)
                    await asyncio.sleep(0.02)

                await asyncio.sleep(0.5)

                latest_metrics = {}
                for ev in reversed(data_events):
                    if ev.get("type") == "turn_metrics":
                        latest_metrics = ev
                        break

            finally:
                listen_task.cancel()
                await audio_stream.aclose()

            tool_called = latest_metrics.get("tool_called")
            tool_exec_ms = latest_metrics.get("tool_execution_ms")
            tool_rt_ms = latest_metrics.get("tool_roundtrip_ms")
            llm_ttft = latest_metrics.get("llm_ttft_ms")
            tts_ttfb = latest_metrics.get("tts_ttfb_ms")
            agent_resp = latest_metrics.get("agent_response", "")

            print(f"  [SERVER METRICS] Tool: {tool_called} | Exec: {tool_exec_ms} ms | RT: {tool_rt_ms} ms | LLM TTFT: {llm_ttft} ms | TTS TTFB: {tts_ttfb} ms")
            print(f"  [AGENT RESPONSE] \"{agent_resp[:60]}...\"")

            record = {
                "trial_num": trial_num,
                "type": trial_type,
                "name": name,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "client_perceived_latency_ms": round(client_latency_ms, 1),
                "audible_peak": heard_peak,
                "tool_called": tool_called,
                "tool_execution_ms": tool_exec_ms,
                "tool_roundtrip_ms": tool_rt_ms,
                "llm_ttft_ms": llm_ttft,
                "tts_ttfb_ms": tts_ttfb,
                "agent_response": agent_resp,
                "status": latest_metrics.get("status", "success"),
            }
            results.append(record)
            with open(RESULTS_FILE, "a", encoding="utf-8") as f:
                f.write(json.dumps(record) + "\n")

    finally:
        await room.disconnect()

    # Print Summary Table
    print("\n" + "=" * 70)
    print("TOOL-OVERHEAD BENCHMARK RESULTS SUMMARY")
    print("=" * 70)
    plain_trials = [r for r in results if r["type"] == "plain_qa"]
    tool_trials = [r for r in results if r["type"] == "tool_call"]

    plain_latencies = [r["client_perceived_latency_ms"] for r in plain_trials if r.get("client_perceived_latency_ms")]
    tool_latencies = [r["client_perceived_latency_ms"] for r in tool_trials if r.get("client_perceived_latency_ms")]

    plain_med = float(np.median(plain_latencies)) if plain_latencies else 0.0
    tool_med = float(np.median(tool_latencies)) if tool_latencies else 0.0
    delta_med = tool_med - plain_med

    tool_execs = [r["tool_execution_ms"] for r in tool_trials if r.get("tool_execution_ms") is not None]
    tool_rts = [r["tool_roundtrip_ms"] for r in tool_trials if r.get("tool_roundtrip_ms") is not None]

    avg_exec = np.mean(tool_execs) if tool_execs else 0.0
    avg_rt = np.mean(tool_rts) if tool_rts else 0.0

    print(f"{'Category':<22} | {'Trials':<6} | {'Median Latency':<16} | {'Mean Latency':<14} | {'Tool Roundtrip'}")
    print("-" * 75)
    print(f"{'Plain Q&A (1 LLM)':<22} | {len(plain_latencies):<6} | {plain_med:<16.1f} | {np.mean(plain_latencies):<14.1f} | N/A (0 ms)")
    print(f"{'Tool-Assisted (2 LLMs)':<22} | {len(tool_latencies):<6} | {tool_med:<16.1f} | {np.mean(tool_latencies):<14.1f} | {avg_rt:.1f} ms (exec: {avg_exec:.1f} ms)")
    print("-" * 75)
    print(f"MEASURED TOOL OVERHEAD DELTA: +{delta_med:.1f} ms client-perceived latency")
    print("=" * 70)


if __name__ == "__main__":
    asyncio.run(main())
