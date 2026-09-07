import json
from pathlib import Path

def analyze():
    with open('bench/client_perceived_results.jsonl', encoding='utf-8') as f:
        burst_client = [json.loads(line) for line in f]
    with open('bench/client_perceived_human_paced.jsonl', encoding='utf-8') as f:
        human_client = [json.loads(line) for line in f]

    print("=== CLIENT LATENCY COMPARISON ===")
    burst_lats = [b['client_perceived_latency_ms'] for b in burst_client]
    human_lats = [h['client_perceived_latency_ms'] for h in human_client]
    print(f"Burst client lats (n={len(burst_lats)}): min={min(burst_lats):.1f}, med={sorted(burst_lats)[len(burst_lats)//2]:.1f}, mean={sum(burst_lats)/len(burst_lats):.1f}, max={max(burst_lats):.1f}")
    print(f"Human client lats (n={len(human_lats)}): min={min(human_lats):.1f}, med={sorted(human_lats)[len(human_lats)//2]:.1f}, mean={sum(human_lats)/len(human_lats):.1f}, max={max(human_lats):.1f}")

    # Inspect matching server records for human run
    with open('streaming_results.jsonl', encoding='utf-8') as f:
        server_records = [json.loads(line) for line in f if line.strip()]

    human_start = human_client[0]['timestamp']
    human_end = human_client[-1]['timestamp']
    print(f"\nHuman client time range: {human_start} -> {human_end}")

    matching = [r for r in server_records if human_start <= r['timestamp'] <= '2026-09-06T13:05:00']
    print(f"Matching server records during human run: {len(matching)}")
    
    server_lats = [m['latency_ms'] for m in matching if m.get('latency_ms') is not None]
    eou_delays = [m['eou_delay_ms'] for m in matching if m.get('eou_delay_ms') is not None]
    llm_ttfts = [m['llm_ttft_ms'] for m in matching if m.get('llm_ttft_ms') is not None]
    rime_ttfbs = [m['tts_ttfb_ms'] for m in matching if m.get('tts_ttfb_ms') is not None]

    if server_lats:
        print(f"Human Server E2E Latency: min={min(server_lats):.1f}, med={sorted(server_lats)[len(server_lats)//2]:.1f}, mean={sum(server_lats)/len(server_lats):.1f}, max={max(server_lats):.1f}")
    if eou_delays:
        print(f"Human EOU Delays: min={min(eou_delays):.1f}, med={sorted(eou_delays)[len(eou_delays)//2]:.1f}, mean={sum(eou_delays)/len(eou_delays):.1f}, max={max(eou_delays):.1f}")
    if llm_ttfts:
        print(f"Human LLM TTFT: min={min(llm_ttfts):.1f}, med={sorted(llm_ttfts)[len(llm_ttfts)//2]:.1f}, mean={sum(llm_ttfts)/len(llm_ttfts):.1f}, max={max(llm_ttfts):.1f}")
    if rime_ttfbs:
        print(f"Human Rime TTFB: min={min(rime_ttfbs):.1f}, med={sorted(rime_ttfbs)[len(rime_ttfbs)//2]:.1f}, mean={sum(rime_ttfbs)/len(rime_ttfbs):.1f}, max={max(rime_ttfbs):.1f}")

    # Now let's compare server records during burst run (client_perceived_results.jsonl)
    burst_start = burst_client[0]['timestamp']
    burst_end = burst_client[-1]['timestamp']
    print(f"\nBurst client time range: {burst_start} -> {burst_end}")
    matching_burst = [r for r in server_records if burst_start <= r['timestamp'] <= burst_end]
    print(f"Matching server records during burst run: {len(matching_burst)}")
    b_server_lats = [m['latency_ms'] for m in matching_burst if m.get('latency_ms') is not None]
    b_eou_delays = [m['eou_delay_ms'] for m in matching_burst if m.get('eou_delay_ms') is not None]
    b_llm_ttfts = [m['llm_ttft_ms'] for m in matching_burst if m.get('llm_ttft_ms') is not None]
    b_rime_ttfbs = [m['tts_ttfb_ms'] for m in matching_burst if m.get('tts_ttfb_ms') is not None]
    if b_server_lats:
        print(f"Burst Server E2E Latency: min={min(b_server_lats):.1f}, med={sorted(b_server_lats)[len(b_server_lats)//2]:.1f}, mean={sum(b_server_lats)/len(b_server_lats):.1f}, max={max(b_server_lats):.1f}")
    if b_eou_delays:
        print(f"Burst EOU Delays: min={min(b_eou_delays):.1f}, med={sorted(b_eou_delays)[len(b_eou_delays)//2]:.1f}, mean={sum(b_eou_delays)/len(b_eou_delays):.1f}, max={max(b_eou_delays):.1f}")
    if b_llm_ttfts:
        print(f"Burst LLM TTFT: min={min(b_llm_ttfts):.1f}, med={sorted(b_llm_ttfts)[len(b_llm_ttfts)//2]:.1f}, mean={sum(b_llm_ttfts)/len(b_llm_ttfts):.1f}, max={max(b_llm_ttfts):.1f}")
    if b_rime_ttfbs:
        print(f"Burst Rime TTFB: min={min(b_rime_ttfbs):.1f}, med={sorted(b_rime_ttfbs)[len(b_rime_ttfbs)//2]:.1f}, mean={sum(b_rime_ttfbs)/len(b_rime_ttfbs):.1f}, max={max(b_rime_ttfbs):.1f}")

if __name__ == '__main__':
    analyze()
