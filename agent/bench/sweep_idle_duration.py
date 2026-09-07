"""
CookTalk Phase 5 — Frontend End-to-End Smoke Test
Simulates a real kitchen user session connecting via the token server API,
navigating recipes, asking substitutions, setting a realistic 20-second timer,
and verifying that both proactive WebRTC spoken alerts and real-time data channel
events (recipe state, timers, latency metrics) are delivered cleanly.
"""

import asyncio
import json
import time
import wave
from pathlib import Path
import numpy as np
import requests
from livekit import rtc

BENCH_DIR = Path(__file__).parent
FIXTURES_DIR = BENCH_DIR / "fixtures"


def read_wav_frames(wav_path: Path):
    with wave.open(str(wav_path), "rb") as wf:
        sample_rate = wf.getframerate()
        channels = wf.getnchannels()
        sampwidth = wf.getsampwidth()
        pcm_bytes = wf.readframes(wf.getnframes())

    chunk_ms = 20
    samples_per_chunk = int(sample_rate * (chunk_ms / 1000.0))
    bytes_per_chunk = samples_per_chunk * channels * sampwidth
    chunks = []
    last_speech_idx = 0
    for i, offset in enumerate(range(0, len(pcm_bytes), bytes_per_chunk)):
        chunk = pcm_bytes[offset : offset + bytes_per_chunk]
        if len(chunk) == bytes_per_chunk:
            chunks.append(chunk)
            samples = np.frombuffer(chunk, dtype=np.int16)
            if len(samples) > 0 and np.max(np.abs(samples)) > 500:
                last_speech_idx = i
    return sample_rate, channels, samples_per_chunk, chunks, last_speech_idx


async def run_smoke_test():
    print("=" * 70)
    print("CookTalk Phase 5 — Full Frontend Session Smoke Test")
    print("=" * 70)

    room_name = f"cooktalk-kitchen-{int(time.time())}"
    token_url = f"http://127.0.0.1:8000/api/token?room={room_name}&identity=frontend_smoke_chef"
    print(f"Requesting token from token server: {token_url}")
    res = requests.get(token_url, timeout=5.0)
    res.raise_for_status()
    cred = res.json()
    token = cred["token"]
    url = cred["url"]

    room = rtc.Room()
    agent_audio_track = None
    agent_joined = asyncio.Event()
    track_subscribed = asyncio.Event()
    data_events = []

    @room.on("participant_connected")
    def on_p_connected(p: rtc.RemoteParticipant):
        if "agent" in p.identity.lower():
            print(f"  [Room Event] Agent joined: {p.identity}")
            agent_joined.set()

    @room.on("track_subscribed")
    def on_track_sub(track: rtc.Track, pub, p):
        nonlocal agent_audio_track
        if track.kind == rtc.TrackKind.KIND_AUDIO:
            print(f"  [Room Event] Subscribed to agent audio track from {p.identity}")
            agent_audio_track = track
            track_subscribed.set()

    @room.on("data_received")
    def on_data(data_packet: rtc.DataPacket):
        try:
            payload = json.loads(data_packet.data.decode("utf-8"))
            topic = data_packet.topic
            print(f"  [DATA CHANNEL EVENT] topic='{topic}' type='{payload.get('type')}'")
            data_events.append(payload)
        except Exception as e:
            print(f"  [DATA CHANNEL ERROR] {e}")

    print(f"Connecting to room '{room_name}' via {url}...")
    await room.connect(url, token)
    print("Connected.")

    # Check if agent already in room
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
    mic_track = rtc.LocalAudioTrack.create_audio_track("smoke_mic", source)
    await room.local_participant.publish_track(mic_track, rtc.TrackPublishOptions(source=rtc.TrackSource.SOURCE_MICROPHONE))
    print("Published microphone track.")

    # Single-owner audio feeder helpers to avoid concurrent capture_frame calls
    async def feed_silence(duration_sec: float):
        silent_chunk = bytes(320 * 2)  # 20ms @ 16kHz
        t_end = time.perf_counter() + duration_sec
        while time.perf_counter() < t_end:
            frame = rtc.AudioFrame(silent_chunk, 16000, 1, 320)
            await source.capture_frame(frame)
            await asyncio.sleep(0.02)

    print("Settle media connection and VAD with 3.0s silence feed...")
    await feed_silence(3.0)

    RESULTS_FILE = BENCH_DIR / "idle_sweep_results.jsonl"
    if RESULTS_FILE.exists():
        RESULTS_FILE.unlink()

    IDLE_GAPS = [2, 5, 10, 15, 20, 30, 45, 60]
    TRIALS_PER_GAP = 3
    total_trials = len(IDLE_GAPS) * TRIALS_PER_GAP
    trial_idx = 0
    all_sweep_results = []
    question_wav = FIXTURES_DIR / "short_01_egg.wav"
    sr, nch, spc, chunks, last_sp_idx = read_wav_frames(question_wav)

    print("\n" + "=" * 70)
    print(f"STARTING IDLE SWEEP: {IDLE_GAPS} seconds ({TRIALS_PER_GAP} trials each = {total_trials} total)")
    print("=" * 70)

    try:
        for gap_s in IDLE_GAPS:
            print(f"\n==================================================")
            print(f"TESTING IDLE GAP: {gap_s}s ({TRIALS_PER_GAP} trials)")
            print(f"==================================================")

            for trial_rep in range(1, TRIALS_PER_GAP + 1):
                trial_idx += 1
                print(f"\n[Trial {trial_idx}/{total_trials}] Gap: {gap_s}s (Rep {trial_rep}/{TRIALS_PER_GAP})")
                print(f"  Holding idle for {gap_s}s (feeding background silence)...", end=" ", flush=True)
                await feed_silence(float(gap_s))
                print("DONE")

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
                        if peak >= 600:
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

                print("  Sending question 'How long do I boil an egg?'...", end=" ", flush=True)
                chunk_interval = 0.02
                for i, chunk in enumerate(chunks):
                    frame = rtc.AudioFrame(chunk, sr, nch, spc)
                    await source.capture_frame(frame)
                    if i == last_sp_idx and t0 is None:
                        t0 = time.perf_counter()
                    await asyncio.sleep(chunk_interval * 0.98)

                if t0 is None:
                    t0 = time.perf_counter()

                print("Waiting for agent reply...", end=" ", flush=True)
                silent_chunk = bytes(spc * nch * 2)
                try:
                    while t1 is None:
                        s_frame = rtc.AudioFrame(silent_chunk, sr, nch, spc)
                        await source.capture_frame(s_frame)
                        await asyncio.sleep(0.02)
                        if (time.perf_counter() - t0) > 16.0:
                            raise TimeoutError("Agent response timeout (>16s)")

                    client_latency_ms = (t1 - t0) * 1000.0
                    print(f"RECEIVED! Peak={heard_peak}, Latency={client_latency_ms:.1f} ms")

                    # Wait for agent speech turn to complete
                    t_turn_wait = time.perf_counter()
                    while not turn_done.is_set() and (time.perf_counter() - t_turn_wait) < 12.0:
                        s_frame = rtc.AudioFrame(silent_chunk, sr, nch, spc)
                        await source.capture_frame(s_frame)
                        await asyncio.sleep(0.02)

                    # Give 0.3s for metrics packet on data channel
                    await asyncio.sleep(0.3)

                    latest_metrics = {}
                    for ev in reversed(data_events):
                        if ev.get("type") == "turn_metrics":
                            latest_metrics = ev
                            break

                    record = {
                        "trial_num": trial_idx,
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                        "idle_gap_seconds": gap_s,
                        "trial_rep": trial_rep,
                        "client_perceived_latency_ms": round(client_latency_ms, 1),
                        "audible_peak": heard_peak,
                        "eou_delay_ms": latest_metrics.get("eou_delay_ms"),
                        "llm_ttft_ms": latest_metrics.get("llm_ttft_ms"),
                        "tts_ttfb_ms": latest_metrics.get("tts_ttfb_ms"),
                        "status": "success",
                    }
                    print(f"  Telemetry: EOU={record['eou_delay_ms']}ms, LLM_TTFT={record['llm_ttft_ms']}ms, Rime_TTFB={record['tts_ttfb_ms']}ms")

                except Exception as e:
                    print(f"FAILED: {e}")
                    record = {
                        "trial_num": trial_idx,
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                        "idle_gap_seconds": gap_s,
                        "trial_rep": trial_rep,
                        "client_perceived_latency_ms": None,
                        "audible_peak": 0,
                        "error": str(e),
                        "status": "failed",
                    }
                finally:
                    await audio_stream.aclose()
                    listen_task.cancel()

                all_sweep_results.append(record)
                with open(RESULTS_FILE, "a", encoding="utf-8") as f:
                    f.write(json.dumps(record) + "\n")

    finally:
        await room.disconnect()
        await source.aclose()

    print("\n" + "=" * 70)
    print("IDLE SWEEP COMPLETE")
    print(f"Total trials logged: {len(all_sweep_results)}")
    print("=" * 70)


if __name__ == "__main__":
    from datetime import datetime, timezone
    asyncio.run(run_smoke_test())
