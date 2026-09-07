"""
Generate exact WAV audio fixtures for demo-script queries using Rime API.
Ensures exactly 1.0s trailing silence for reliable Silero VAD endpointing.
"""

import os
import wave
from pathlib import Path
import httpx
from dotenv import load_dotenv

ENV_PATH = Path(__file__).parent.parent.parent / ".env"
load_dotenv(ENV_PATH)

RIME_API_KEY = os.getenv("RIME_API_KEY")
RIME_TTS_URL = "https://users.rime.ai/v1/rime-tts"
FIXTURES_DIR = Path(__file__).parent / "fixtures"
FIXTURES_DIR.mkdir(parents=True, exist_ok=True)

DEMO_PROMPTS = [
    {
        "id": "demo_01_ingredients",
        "text": "What ingredients do I need for Cacio e Pepe?",
    },
    {
        "id": "demo_02_substitution",
        "text": "What if I don't have Pecorino Romano?",
    },
    {
        "id": "demo_03_next_step",
        "text": "Got it. What is the next step?",
    },
    {
        "id": "demo_04_steak_science",
        "text": "I have some aged ribeye steak in the fridge and want to make sure the internal temperature doesn't overshoot medium rare. Can you explain the science of carryover cooking and what temperature I should pull it off the heat?",
    },
    {
        "id": "demo_05_timer_toast",
        "text": "Set a timer for 20 seconds for the pepper toast.",
    },
]

headers = {
    "Authorization": f"Bearer {RIME_API_KEY}",
    "Content-Type": "application/json",
}

for p in DEMO_PROMPTS:
    out_file = FIXTURES_DIR / f"{p['id']}.wav"
    if out_file.exists():
        print(f"Fixture {out_file.name} already exists.")
        continue

    print(f"Generating fixture {out_file.name} via Rime TTS...")
    payload = {
        "speaker": "astra",
        "modelId": "coda",
        "text": p["text"],
        "audioFormat": "wav",
        "samplingRate": 16000,
        "speedAlpha": 1.0,
    }
    resp = httpx.post(RIME_TTS_URL, headers=headers, json=payload, timeout=20.0)
    resp.raise_for_status()
    data = resp.content
    data_idx = data.find(b"data")
    if data_idx != -1:
        raw_pcm = data[data_idx + 8:]
    else:
        raw_pcm = data

    sr = 16000
    nch = 1
    sw = 2
    silence = b"\x00" * int(sr * 1.0 * nch * sw)  # 1.0s clean trailing silence
    with wave.open(str(out_file), "wb") as wf_out:
        wf_out.setnchannels(nch)
        wf_out.setsampwidth(sw)
        wf_out.setframerate(sr)
        wf_out.writeframes(raw_pcm + silence)
    print(f"Saved {out_file.name} ({len(raw_pcm + silence)} bytes)")

print("All demo fixtures ready.")
