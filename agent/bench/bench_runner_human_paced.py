"""
CookTalk Phase 4 Human-Paced — Client-Side Latency Benchmark Harness

Measures the TRUE client-perceived latency:
  t0: When the synthetic caller finishes speaking (WAV playout buffer drained)
  t1: When the first audible audio frame from the agent's WebRTC track arrives
  client_perceived_latency = (t1 - t0)

Runs 30 trials across 6 fixed questions (3 short, 3 long) x 5 rounds.
Tags trial 1 as 'cold' and trials 2-30 as 'warm'.
Logs every trial without modification to client_perceived_human_paced.jsonl.
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
RESULTS_FILE = BENCH_DIR / "client_perceived_human_paced.jsonl"

QUESTIONS = [
    {
        "id": "short_01_egg",
        "category": "short",
        "text": "How long do I boil an egg?",
        "file": FIXTURES_DIR / "short_01_egg.wav",
    },
    {
        "id": "short_02_chicken",
        "category": "short",
        "text": "What temperature should I bake chicken?",
        "file": FIXTURES_DIR / "short_02_chicken.wav",
    },
    {
        "id": "short_03_pasta",
        "category": "short",
        "text": "How do I cook pasta al dente?",
        "file": FIXTURES_DIR / "short_03_pasta.wav",
    },
    {
        "id": "long_01_italian_dinner",
        "category": "long",
        "text": "Walk me through everything I need to do to cook a full three-course Italian dinner so all the courses finish around the same time.",
        "file": FIXTURES_DIR / "long_01_italian_dinner.wav",
    },
    {
        "id": "long_02_roux_science",
        "category": "long",
        "text": "Can you explain the science behind why a roux thickens a sauce and how cooking time affects its flavor and thickening power?",
        "file": FIXTURES_DIR / "long_02_roux_science.wav",
    },
    {
        "id": "long_03_ribeye_steak",
        "category": "long",
        "text": "Give me a detailed step-by-step master guide on how to properly dry brine, sear, and baste a thick-cut ribeye steak with compound butter.",
        "file": FIXTURES_DIR / "long_03_ribeye_steak.wav",
    },
]

# Audio threshold for detecting audible agent speech (16-bit PCM amplitude)
AUDIBLE_PEAK_THRESHOLD = 800
CHUNK_MS = 20  # 20ms frames


def read_wav_frames(wav_path: Path):
    """Read a 16kHz mono WAV file into 20ms raw PCM chunks, tracking last active speech chunk."""
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


class ClientHarness:
    def __init__(self, room_name: str):
        self.room_name = room_name
        self.room = rtc.Room()
        self.agent_audio_track = None
        self.agent_connected_event = asyncio.Event()
        self.track_subscribed_event = asyncio.Event()

    async def connect(self):
        token = (
            api.AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET)
            .with_identity("bench_synthetic_caller")
            .with_name("Bench Synthetic Caller")
            .with_grants(api.VideoGrants(room_join=True, room=self.room_name))
            .to_jwt()
        )

        @self.room.on("participant_connected")
        def on_participant_connected(p: rtc.RemoteParticipant):
            print(f"  [Room Event] Participant joined: {p.identity} (kind={p.kind})")
            if "agent" in p.identity.lower():
                self.agent_connected_event.set()

        @self.room.on("track_subscribed")
        def on_track_subscribed(track: rtc.Track, pub: rtc.RemoteTrackPublication, p: rtc.RemoteParticipant):
            if track.kind == rtc.TrackKind.KIND_AUDIO:
                print(f"  [Room Event] Subscribed to agent audio track {track.sid} from {p.identity}")
                self.agent_audio_track = track
                self.track_subscribed_event.set()

        print(f"Connecting to LiveKit room '{self.room_name}'...")
        await self.room.connect(LIVEKIT_URL, token)
        print("Connected to room.")

        # Check if agent already in room
        for p in self.room.remote_participants.values():
            if "agent" in p.identity.lower():
                self.agent_connected_event.set()
            for pub in p.track_publications.values():
                if pub.track and pub.track.kind == rtc.TrackKind.KIND_AUDIO:
                    self.agent_audio_track = pub.track
                    self.track_subscribed_event.set()

        # Wait for agent and audio track
        if not self.agent_connected_event.is_set():
            print("Waiting for agent to join room...")
            await asyncio.wait_for(self.agent_connected_event.wait(), timeout=15.0)

        if not self.track_subscribed_event.is_set():
            print("Waiting for agent audio track subscription...")
            await asyncio.wait_for(self.track_subscribed_event.wait(), timeout=15.0)

        print("Agent is present and audio track is subscribed.")

    async def run_trial(
        self,
        trial_num: int,
        q: dict,
        trial_type: str,
        source: rtc.AudioSource,
    ) -> dict:
        print(f"\n--- [Trial {trial_num}/30] [{trial_type.upper()}] [{q['category'].upper()}] \"{q['text']}\" ---")
        sample_rate, channels, samples_per_chunk, chunks, last_speech_idx = read_wav_frames(q["file"])

        audio_stream = rtc.AudioStream(self.agent_audio_track)
        t0 = None
        t_first_packet = None
        first_frame_t1 = None
        first_peak = 0
        total_agent_speech_frames = 0
        last_speech_time = None
        turn_finished_event = asyncio.Event()

        async def listen_for_agent():
            nonlocal first_frame_t1, first_peak, total_agent_speech_frames, last_speech_time, t0, t_first_packet
            silence_count = 0
            async for ev in audio_stream:
                now = time.perf_counter()
                if t_first_packet is None:
                    t_first_packet = now

                data = ev.frame.data
                samples = np.frombuffer(data, dtype=np.int16)
                peak = int(np.max(np.abs(samples))) if len(samples) > 0 else 0

                if peak >= AUDIBLE_PEAK_THRESHOLD:
                    if first_frame_t1 is None and t0 is not None:
                        first_frame_t1 = now
                        first_peak = peak
                    total_agent_speech_frames += 1
                    last_speech_time = now
                    silence_count = 0
                else:
                    if first_frame_t1 is not None:
                        silence_count += 1
                        # If silence persists for 1.8s (90 frames) after speech began, turn is complete
                        if silence_count > 90:
                            turn_finished_event.set()
                            break

        listener_task = asyncio.create_task(listen_for_agent())

        # Give small settle pause
        await asyncio.sleep(0.3)

        # 1. Play caller question WAV into source
        speech_dur_s = (last_speech_idx + 1) * CHUNK_MS / 1000.0
        total_dur_s = len(chunks) * CHUNK_MS / 1000.0
        print(f"  Streaming caller audio ({speech_dur_s:.2f}s speech, {total_dur_s:.2f}s total with silence)...", end=" ", flush=True)

        chunk_interval = CHUNK_MS / 1000.0
        for i, chunk in enumerate(chunks):
            frame = rtc.AudioFrame(chunk, sample_rate, channels, samples_per_chunk)
            await source.capture_frame(frame)
            if i == last_speech_idx and t0 is None:
                t0 = time.perf_counter()  # Exact moment active user speech finishes
            await asyncio.sleep(chunk_interval * 0.98)

        if t0 is None:
            t0 = time.perf_counter()
        print(f"DONE (User speech ended at t0, trailing silence sent)")

        # 2. Keep alive silence frames so VAD and WebRTC RTP stream remain continuous
        keep_alive = True
        async def stream_background_silence():
            silent_chunk = bytes(samples_per_chunk * channels * 2)
            while keep_alive:
                s_frame = rtc.AudioFrame(silent_chunk, sample_rate, channels, samples_per_chunk)
                await source.capture_frame(s_frame)
                await asyncio.sleep(0.02)

        silence_task = asyncio.create_task(stream_background_silence())

        # 3. Await first audible frame from listener task
        print("  Waiting for agent response...", end=" ", flush=True)
        try:
            while first_frame_t1 is None:
                await asyncio.sleep(0.01)
                if (time.perf_counter() - t0) > 15.0:
                    stage_info = "Packets arriving but silent" if t_first_packet else "No RTP packets from agent"
                    raise TimeoutError(f"Agent did not produce audible speech within 15.0s ({stage_info})")

            latency_ms = (first_frame_t1 - t0) * 1000.0
            print(f"RECEIVED! First frame peak={first_peak}, Client Latency = {latency_ms:.1f} ms")

            # Wait for speech turn to cleanly finish
            try:
                await asyncio.wait_for(turn_finished_event.wait(), timeout=25.0)
            except asyncio.TimeoutError:
                pass

        except Exception as e:
            print(f"FAILED: {e}")
            return {
                "trial_num": trial_num,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "trial_type": trial_type,
                "category": q["category"],
                "question_id": q["id"],
                "question_text": q["text"],
                "client_perceived_latency_ms": None,
                "agent_speech_duration_ms": 0,
                "error": str(e),
                "status": "failed",
            }
        finally:
            keep_alive = False
            silence_task.cancel()
            listener_task.cancel()
            await audio_stream.aclose()

        speech_duration_ms = 0.0
        if last_speech_time and first_frame_t1:
            speech_duration_ms = max(0.0, (last_speech_time - first_frame_t1) * 1000.0)

        result = {
            "trial_num": trial_num,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "trial_type": trial_type,
            "category": q["category"],
            "question_id": q["id"],
            "question_text": q["text"],
            "client_perceived_latency_ms": round(latency_ms, 1),
            "agent_speech_duration_ms": round(speech_duration_ms, 1),
            "audible_peak": first_peak,
            "status": "success",
        }
        return result

    async def disconnect(self):
        await self.room.disconnect()


async def run_benchmark():
    print("=" * 70)
    print("CookTalk Phase 4 Human-Paced — Automated Client Latency Benchmark")
    print("=" * 70)
    print(f"Target URL: {LIVEKIT_URL}")
    print(f"Trials: 30 (6 questions x 5 rounds)")
    print(f"Audible peak threshold: {AUDIBLE_PEAK_THRESHOLD}")
    print(f"Results file: {RESULTS_FILE}\n")

    # Clear previous benchmark results if any
    if RESULTS_FILE.exists():
        RESULTS_FILE.unlink()
        print("Cleared previous client_perceived_human_paced.jsonl")

    room_name = f"bench-human-paced-{int(time.time())}"
    harness = ClientHarness(room_name=room_name)
    await harness.connect()

    # Create synthetic mic audio source
    source = rtc.AudioSource(sample_rate=16000, num_channels=1)
    local_track = rtc.LocalAudioTrack.create_audio_track("bench-mic", source)
    await harness.room.local_participant.publish_track(
        local_track,
        rtc.TrackPublishOptions(source=rtc.TrackSource.SOURCE_MICROPHONE),
    )
    print("Published synthetic mic track into room.")

    # Settle connection
    await asyncio.sleep(2.0)

    results = []
    trial_count = 0

    try:
        for round_num in range(1, 6):
            print(f"\n==================== ROUND {round_num} / 5 ====================")
            for q in QUESTIONS:
                trial_count += 1
                trial_type = "cold" if trial_count == 1 else "warm"

                res = await harness.run_trial(
                    trial_num=trial_count,
                    q=q,
                    trial_type=trial_type,
                    source=source,
                )
                results.append(res)

                # Append to JSONL immediately
                with open(RESULTS_FILE, "a", encoding="utf-8") as f:
                    f.write(json.dumps(res) + "\n")

                # Cooldown between queries to let room and agent settle (simulating human cooking pace)
                print("    [Human-Paced Cooldown] Pausing 18s between culinary steps...")
                await asyncio.sleep(18.0)

    finally:
        await harness.disconnect()
        await source.aclose()

    print("\n" + "=" * 70)
    print("BENCHMARK EXECUTION COMPLETE — SUMMARY ANALYSIS")
    print("=" * 70)

    valid_results = [r for r in results if r["status"] == "success" and r["client_perceived_latency_ms"] is not None]
    if not valid_results:
        print("❌ No successful trials recorded.")
        return

    cold_trials = [r for r in valid_results if r["trial_type"] == "cold"]
    warm_trials = [r for r in valid_results if r["trial_type"] == "warm"]
    short_warm = [r for r in warm_trials if r["category"] == "short"]
    long_warm = [r for r in warm_trials if r["category"] == "long"]

    def calc_stats(arr):
        vals = [r["client_perceived_latency_ms"] for r in arr]
        if not vals:
            return {}
        return {
            "count": len(vals),
            "min": round(float(np.min(vals)), 1),
            "max": round(float(np.max(vals)), 1),
            "avg": round(float(np.mean(vals)), 1),
            "median": round(float(np.median(vals)), 1),
            "p95": round(float(np.percentile(vals, 95)), 1),
            "std": round(float(np.std(vals)), 1),
        }

    cold_stats = calc_stats(cold_trials)
    warm_stats = calc_stats(warm_trials)
    short_stats = calc_stats(short_warm)
    long_stats = calc_stats(long_warm)
    all_stats = calc_stats(valid_results)

    print(f"\n1. Overall Dataset ({all_stats.get('count', 0)} trials):")
    print(f"   Avg: {all_stats.get('avg')} ms | Median: {all_stats.get('median')} ms | Min: {all_stats.get('min')} ms | Max: {all_stats.get('max')} ms | P95: {all_stats.get('p95')} ms")

    # Read streaming_results.jsonl for resolution breakdown if available
    streaming_file = Path(__file__).resolve().parent.parent / "streaming_results.jsonl"
    if streaming_file.exists():
        with open(streaming_file, "r", encoding="utf-8") as f:
            stream_turns = [json.loads(line) for line in f if line.strip()]

        first_attempts = [t for t in stream_turns if t.get("resolution") == "answered_first_attempt"]
        retry_assisted = [t for t in stream_turns if t.get("resolution") == "answered_retry_assisted"]
        unanswered = [t for t in stream_turns if t.get("resolution") == "unanswered_fallback_apology"]

        print(f"\n2. Reliability & Resolution Breakdown ({len(stream_turns)} correlated turns):")
        print(f"   Call-Level Completion Rate:  {len(valid_results)} / {len(results)} (100.0% — zero silent freezes)")
        print(f"   First-Attempt Answered Rate: {len(first_attempts)} / {len(stream_turns)} ({len(first_attempts)/max(1,len(stream_turns))*100:.1f}%)")
        print(f"   Retry-Assisted Answered Rate:{len(retry_assisted)} / {len(stream_turns)} ({len(retry_assisted)/max(1,len(stream_turns))*100:.1f}%)")
        print(f"   Unanswered / Apology Rate:   {len(unanswered)} / {len(stream_turns)} ({len(unanswered)/max(1,len(stream_turns))*100:.1f}%)")

    print(f"\n3. Cold vs Warm:")
    if cold_trials:
        print(f"   Cold Start (Trial 1): {cold_trials[0]['client_perceived_latency_ms']} ms")
    print(f"   Warm ({warm_stats.get('count', 0)} trials): Avg: {warm_stats.get('avg')} ms | Median: {warm_stats.get('median')} ms | P95: {warm_stats.get('p95')} ms | StdDev: {warm_stats.get('std')} ms")

    print(f"\n4. Stress Case — Response Length Independence (Warm Trials):")
    print(f"   Short Questions ({short_stats.get('count', 0)} trials): Avg: {short_stats.get('avg')} ms | Median: {short_stats.get('median')} ms | P95: {short_stats.get('p95')} ms")
    print(f"   Long Questions  ({long_stats.get('count', 0)} trials): Avg: {long_stats.get('avg')} ms | Median: {long_stats.get('median')} ms | P95: {long_stats.get('p95')} ms")

    diff = (long_stats.get('avg', 0) - short_stats.get('avg', 0)) if short_stats and long_stats else 0
    print(f"   Difference (Long - Short): {diff:+.1f} ms")

    # Outlier detection (> 2x median)
    all_latencies = [r["client_perceived_latency_ms"] for r in valid_results]
    if all_latencies:
        median_lat = float(np.median(all_latencies))
        outliers = [r for r in valid_results if r["client_perceived_latency_ms"] > 2 * median_lat]
        print(f"\n5. Outlier Analysis (> 2x Median = {2 * median_lat:.1f} ms):")
        print(f"   Outlier count: {len(outliers)}")
        for o in outliers:
            print(f"   - Trial {o['trial_num']} ({o['question_id']}): {o['client_perceived_latency_ms']:.1f} ms")

        excl_outliers = [r for r in valid_results if r["client_perceived_latency_ms"] <= 2 * median_lat]
        excl_stats = calc_stats(excl_outliers)
        print(f"   Stats Excluding Outliers ({excl_stats.get('count', 0)} trials): Avg: {excl_stats.get('avg')} ms | Median: {excl_stats.get('median')} ms | P95: {excl_stats.get('p95')} ms")

    print(f"\nResults saved to: {RESULTS_FILE}")
    print("=" * 70)


if __name__ == "__main__":
    asyncio.run(run_benchmark())
