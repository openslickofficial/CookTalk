"""
CookTalk Phase 3 — Fixture Audio Generator

Synthesizes 6 fixed questions (3 short, 3 long) via Rime TTS HTTP API once,
saving them as 16 kHz WAV fixtures for the automated client benchmark harness.
"""

import os
import sys
import time
from pathlib import Path
import httpx
from dotenv import load_dotenv

FIXTURES_DIR = Path(__file__).parent / "fixtures"
ENV_PATH = Path(__file__).parent.parent.parent / ".env"

load_dotenv(ENV_PATH)

RIME_API_KEY = os.getenv("RIME_API_KEY")
RIME_TTS_URL = "https://users.rime.ai/v1/rime-tts"
RIME_MODEL = "coda"
RIME_SPEAKER = "astra"

QUESTIONS = [
    {
        "id": "short_01_egg",
        "category": "short",
        "text": "How long do I boil an egg?",
    },
    {
        "id": "short_02_chicken",
        "category": "short",
        "text": "What temperature should I bake chicken?",
    },
    {
        "id": "short_03_pasta",
        "category": "short",
        "text": "How do I cook pasta al dente?",
    },
    {
        "id": "long_01_italian_dinner",
        "category": "long",
        "text": "Walk me through everything I need to do to cook a full three-course Italian dinner so all the courses finish around the same time.",
    },
    {
        "id": "long_02_roux_science",
        "category": "long",
        "text": "Can you explain the science behind why a roux thickens a sauce and how cooking time affects its flavor and thickening power?",
    },
    {
        "id": "long_03_ribeye_steak",
        "category": "long",
        "text": "Give me a detailed step-by-step master guide on how to properly dry brine, sear, and baste a thick-cut ribeye steak with compound butter.",
    },
]


def generate_fixtures():
    if not RIME_API_KEY:
        print("ERROR: RIME_API_KEY is not set.")
        sys.exit(1)

    FIXTURES_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Generating {len(QUESTIONS)} audio fixtures in {FIXTURES_DIR} via Rime TTS ({RIME_MODEL}/{RIME_SPEAKER})...\n")

    headers = {
        "Authorization": f"Bearer {RIME_API_KEY}",
        "Content-Type": "application/json",
        "Accept": "audio/wav",
    }

    for item in QUESTIONS:
        out_path = FIXTURES_DIR / f"{item['id']}.wav"
        if out_path.exists() and out_path.stat().st_size > 1000:
            print(f"[EXISTS] {item['id']}.wav ({out_path.stat().st_size} bytes)")
            continue

        print(f"Synthesizing [{item['category'].upper()}] \"{item['text']}\" -> {item['id']}.wav...", end=" ", flush=True)
        t0 = time.perf_counter()
        resp = httpx.post(
            RIME_TTS_URL,
            headers=headers,
            json={
                "text": item["text"],
                "modelId": RIME_MODEL,
                "speaker": RIME_SPEAKER,
                "samplingRate": 16000,
            },
            timeout=30.0,
        )
        t1 = time.perf_counter()

        if resp.status_code != 200:
            print(f"FAILED (status {resp.status_code}): {resp.text[:200]}")
            sys.exit(1)

        # Append 800ms of clean trailing silence (16kHz mono 16-bit PCM = 32000 bytes/sec * 0.8 = 25600 bytes)
        import wave
        import io
        in_wf = wave.open(io.BytesIO(resp.content), "rb")
        sr = in_wf.getframerate()
        nch = in_wf.getnchannels()
        sw = in_wf.getsampwidth()
        raw_pcm = in_wf.readframes(in_wf.getnframes())
        in_wf.close()

        silence_samples = int(sr * 0.8)  # 800ms silence
        silence_bytes = bytes(silence_samples * nch * sw)
        padded_pcm = raw_pcm + silence_bytes

        with wave.open(str(out_path), "wb") as out_wf:
            out_wf.setnchannels(nch)
            out_wf.setsampwidth(sw)
            out_wf.setframerate(sr)
            out_wf.writeframes(padded_pcm)

        padded_dur = len(padded_pcm) / (sr * nch * sw)
        print(f"DONE ({len(padded_pcm)} bytes, {padded_dur:.2f}s total with 800ms trailing silence, {((t1-t0)*1000):.0f}ms synth)")
        time.sleep(0.5)

    print("\nAll fixtures successfully generated!")


if __name__ == "__main__":
    generate_fixtures()
