"""
CookTalk Phase 1 — Control Baseline Server

Deliberately naive HTTP-based TTS pipeline:
  1. Receives text from frontend
  2. Calls Rime's TTS HTTP endpoint (non-streaming, waits for full response)
  3. Returns audio bytes to the browser

This is the "before" measurement — we need real numbers to prove
Phase 2's streaming approach is actually faster.
"""

import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

load_dotenv()  # loads .env from project root or cwd

RIME_API_KEY = os.getenv("RIME_API_KEY")
RIME_TTS_URL = "https://users.rime.ai/v1/rime-tts"
RIME_MODEL = "coda"  # flagship model — verified from live docs 2026-09-06
RIME_SPEAKER = "astra"  # recommended starter voice — verified
RIME_LANG = "en"

# Canned responses — we're isolating TTS latency, not LLM latency
CANNED_RESPONSES = {
    "default": "For a soft boiled egg, bring water to a rolling boil, then gently lower the egg in and cook for exactly six and a half minutes. Transfer to an ice bath immediately.",
    "boil egg": "Bring a pot of water to a full boil. For soft boiled, cook for six to seven minutes. For hard boiled, cook for ten to twelve minutes. Then transfer to ice water.",
    "rice": "Rinse the rice until the water runs clear. Use a one to two ratio of rice to water. Bring to a boil, then reduce heat to low, cover, and simmer for eighteen minutes.",
    "pasta": "Use a large pot with plenty of salted water, about one tablespoon of salt per quart. Bring to a rolling boil before adding the pasta. Cook according to package directions minus one minute for al dente.",
    "steak": "Let the steak come to room temperature for thirty minutes. Season generously with salt and pepper. Sear in a screaming hot cast iron pan for three to four minutes per side for medium rare.",
}

BASELINE_FILE = Path(__file__).parent / "baseline_results.jsonl"

app = FastAPI(title="CookTalk Control Baseline")

# Allow the frontend (served from same origin or dev server) to call us
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class SynthesizeRequest(BaseModel):
    text: str


class LatencyReport(BaseModel):
    text: str
    latency_ms: float
    timestamp: str | None = None


def pick_canned_response(user_text: str) -> str:
    """Pick a canned response based on simple keyword matching."""
    lower = user_text.lower()
    for keyword, response in CANNED_RESPONSES.items():
        if keyword in lower:
            return response
    return CANNED_RESPONSES["default"]


@app.post("/api/synthesize")
async def synthesize(req: SynthesizeRequest):
    """
    Accept user text, pick a canned response, send it to Rime TTS,
    and return the full audio as MP3 bytes.
    """
    if not RIME_API_KEY:
        raise HTTPException(
            status_code=500,
            detail="RIME_API_KEY not set. Copy .env.example to .env and add your key.",
        )

    response_text = pick_canned_response(req.text)

    # Call Rime TTS — deliberately wait for the FULL response (non-streaming)
    # This is the naive approach we want to measure against.
    headers = {
        "Authorization": f"Bearer {RIME_API_KEY}",
        "Content-Type": "application/json",
        "Accept": "audio/mpeg",  # MP3 for broadest browser compat
    }
    payload = {
        "text": response_text,
        "modelId": RIME_MODEL,
        "speaker": RIME_SPEAKER,
        "lang": RIME_LANG,
        "samplingRate": 24000,
    }

    async with httpx.AsyncClient(timeout=30.0) as client:
        t_start = time.perf_counter()
        rime_resp = await client.post(RIME_TTS_URL, headers=headers, json=payload)
        t_end = time.perf_counter()

    server_latency_ms = (t_end - t_start) * 1000

    if rime_resp.status_code != 200:
        raise HTTPException(
            status_code=rime_resp.status_code,
            detail=f"Rime API error: {rime_resp.text[:500]}",
        )

    audio_bytes = rime_resp.content

    return Response(
        content=audio_bytes,
        media_type="audio/mpeg",
        headers={
            "X-Server-Latency-Ms": f"{server_latency_ms:.1f}",
            "X-Response-Text": response_text[:100],
        },
    )


@app.post("/api/report-latency")
async def report_latency(report: LatencyReport):
    """Receive end-to-end latency from the browser and append to JSONL file."""
    entry = {
        "timestamp": report.timestamp or datetime.now(timezone.utc).isoformat(),
        "text": report.text,
        "latency_ms": report.latency_ms,
    }
    with open(BASELINE_FILE, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry) + "\n")
    return {"status": "recorded", "entry": entry}


@app.get("/api/summary")
async def summary():
    """Return a summary of recorded baseline latencies."""
    if not BASELINE_FILE.exists():
        return {"count": 0, "message": "No results yet."}

    latencies = []
    with open(BASELINE_FILE, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                entry = json.loads(line)
                latencies.append(entry["latency_ms"])

    if not latencies:
        return {"count": 0, "message": "No results yet."}

    return {
        "count": len(latencies),
        "min_ms": round(min(latencies), 1),
        "max_ms": round(max(latencies), 1),
        "avg_ms": round(sum(latencies) / len(latencies), 1),
        "all_ms": [round(l, 1) for l in latencies],
    }


# Serve the static frontend
static_dir = Path(__file__).parent / "static"
if static_dir.exists():
    app.mount("/", StaticFiles(directory=str(static_dir), html=True), name="static")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("server:app", host="0.0.0.0", port=8000, reload=True)
