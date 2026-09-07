import os
import io
import wave
from pathlib import Path
import httpx
from dotenv import load_dotenv

ENV_PATH = Path(__file__).parent.parent.parent / '.env'
load_dotenv(ENV_PATH)

RIME_API_KEY = os.getenv('RIME_API_KEY')
RIME_TTS_URL = 'https://users.rime.ai/v1/rime-tts'
FIXTURES_DIR = Path(__file__).parent / 'fixtures'
FIXTURES_DIR.mkdir(parents=True, exist_ok=True)

PROMPTS = [
    {'id': 'acc_01_start_and_next', 'text': 'Let us make scrambled eggs. What is the first step?'},
    {'id': 'acc_02_next_step', 'text': 'Okay, what is the next step?'},
    {'id': 'acc_03_repeat_step', 'text': 'Can you repeat that step?'},
    {'id': 'acc_04_ingredient_qty', 'text': 'How much butter do I need for the scrambled eggs?'},
    {'id': 'acc_05_substitution', 'text': 'What can I substitute for heavy cream?'},
    {'id': 'acc_06_timer', 'text': 'Set a timer for five seconds for the egg curd formation.'},
    {'id': 'acc_07_out_of_scope', 'text': 'What is the current stock price of Apple?'}
]

headers = {
    'Authorization': f'Bearer {RIME_API_KEY}',
    'Content-Type': 'application/json',
}

for p in PROMPTS:
    out_file = FIXTURES_DIR / f"{p['id']}.wav"
    if out_file.exists():
        print(f"Fixture {out_file.name} already exists.")
        continue
    payload = {
        'speaker': 'astra',
        'modelId': 'coda',
        'text': p['text'],
        'audioFormat': 'wav',
        'samplingRate': 16000,
        'speedAlpha': 1.0,
    }
    resp = httpx.post(RIME_TTS_URL, headers=headers, json=payload, timeout=20.0)
    resp.raise_for_status()
    data = resp.content
    data_idx = data.find(b'data')
    if data_idx != -1:
        raw_pcm = data[data_idx + 8:]
    else:
        raw_pcm = data
    sr = 16000
    nch = 1
    sw = 2
    silence = b'\x00' * int(sr * 1.0 * nch * sw)  # 1.0s clean trailing silence
    with wave.open(str(out_file), 'wb') as wf_out:
        wf_out.setnchannels(nch)
        wf_out.setsampwidth(sw)
        wf_out.setframerate(sr)
        wf_out.writeframes(raw_pcm + silence)
    print(f"Generated fixture: {out_file.name}")

print('Acceptance fixtures ready.')
