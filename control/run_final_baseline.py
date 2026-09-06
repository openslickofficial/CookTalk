"""Final clean baseline run — 5 queries, write all to JSONL, print summary."""
import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

import httpx
import json
import time
from pathlib import Path

SERVER = "http://localhost:8000"
JSONL = Path(__file__).parent / "baseline_results.jsonl"

# Clear previous results
if JSONL.exists():
    JSONL.unlink()

QUERIES = [
    "How long do I boil an egg?",
    "What is the best way to cook rice?",
    "How do I cook pasta al dente?",
    "How do I sear a steak properly?",
    "What temperature should I bake chicken at?",
]

latencies = []
for i, q in enumerate(QUERIES, 1):
    print(f"[{i}/5] {q}")
    t0 = time.perf_counter()
    resp = httpx.post(f"{SERVER}/api/synthesize", json={"text": q}, timeout=30.0)
    t1 = time.perf_counter()
    ms = (t1 - t0) * 1000
    srv = resp.headers.get("X-Server-Latency-Ms", "?")
    print(f"  -> {ms:.0f} ms (server TTS: {srv} ms, {len(resp.content)} bytes)")
    latencies.append(ms)
    httpx.post(
        f"{SERVER}/api/report-latency",
        json={"text": q, "latency_ms": round(ms), "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())},
        timeout=5.0,
    )
    time.sleep(0.3)

print()
print("=" * 50)
print(f"  Requests: {len(latencies)}/5")
print(f"  Min:  {min(latencies):.0f} ms")
print(f"  Max:  {max(latencies):.0f} ms")
print(f"  Avg:  {sum(latencies) / len(latencies):.0f} ms")
print("=" * 50)

# Verify JSONL
lines = [json.loads(line) for line in JSONL.read_text().strip().splitlines()]
print(f"  JSONL entries: {len(lines)}")
for entry in lines:
    lat = entry["latency_ms"]
    txt = entry["text"]
    print(f"    {lat} ms - {txt}")
