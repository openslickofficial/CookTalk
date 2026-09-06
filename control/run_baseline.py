"""
CookTalk Phase 1 - Automated Baseline Test Runner

Sends 5 varied cooking questions through the control server,
records latencies, and prints a summary.

Usage:
  1. Make sure the server is running: python server.py
  2. Run this script: python run_baseline.py
"""
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

import json
import time
from pathlib import Path

import httpx

SERVER_URL = "http://localhost:8000"
BASELINE_FILE = Path(__file__).parent / "baseline_results.jsonl"

TEST_QUERIES = [
    "How long do I boil an egg?",
    "What's the best way to cook rice?",
    "How do I cook pasta al dente?",
    "How do I sear a steak properly?",
    "What temperature should I bake chicken at?",
]


def run_baseline():
    print("=" * 60)
    print("CookTalk Phase 1 — Baseline Latency Test")
    print("=" * 60)
    print(f"Server: {SERVER_URL}")
    print(f"Queries: {len(TEST_QUERIES)}")
    print()

    # Check server is reachable
    try:
        resp = httpx.get(f"{SERVER_URL}/api/summary", timeout=5.0)
        resp.raise_for_status()
    except Exception as e:
        print(f"❌ Cannot reach server at {SERVER_URL}: {e}")
        print("   Start the server first: python server.py")
        sys.exit(1)

    # Clear previous results
    if BASELINE_FILE.exists():
        BASELINE_FILE.unlink()
        print("Cleared previous baseline_results.jsonl")

    latencies = []

    for i, query in enumerate(TEST_QUERIES, 1):
        print(f"\n[{i}/{len(TEST_QUERIES)}] \"{query}\"")
        print("  Sending to Rime TTS...", end=" ", flush=True)

        t0 = time.perf_counter()

        try:
            resp = httpx.post(
                f"{SERVER_URL}/api/synthesize",
                json={"text": query},
                timeout=30.0,
            )
            resp.raise_for_status()
        except Exception as e:
            print(f"❌ Error: {e}")
            continue

        t1 = time.perf_counter()
        e2e_ms = (t1 - t0) * 1000
        server_ms = resp.headers.get("X-Server-Latency-Ms", "?")
        audio_size = len(resp.content)

        print(f"✅ {e2e_ms:.0f} ms (server TTS: {server_ms} ms, audio: {audio_size} bytes)")

        latencies.append(e2e_ms)

        # Report to server for JSONL logging
        httpx.post(
            f"{SERVER_URL}/api/report-latency",
            json={
                "text": query,
                "latency_ms": round(e2e_ms),
                "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            },
            timeout=5.0,
        )

        # Small pause between requests to avoid any rate limiting
        if i < len(TEST_QUERIES):
            time.sleep(0.5)

    # Summary
    print("\n" + "=" * 60)
    print("BASELINE RESULTS SUMMARY")
    print("=" * 60)

    if not latencies:
        print("❌ No successful requests.")
        sys.exit(1)

    print(f"  Requests: {len(latencies)}/{len(TEST_QUERIES)} successful")
    print(f"  Min:      {min(latencies):.0f} ms")
    print(f"  Max:      {max(latencies):.0f} ms")
    print(f"  Avg:      {sum(latencies) / len(latencies):.0f} ms")
    print(f"  Results:  {BASELINE_FILE}")

    # Also fetch the server's summary
    try:
        summary = httpx.get(f"{SERVER_URL}/api/summary", timeout=5.0).json()
        print(f"\n  Server JSONL summary: {summary}")
    except Exception:
        pass

    print("\n✅ Baseline test complete.")
    return latencies


if __name__ == "__main__":
    run_baseline()
