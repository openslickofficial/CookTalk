# CookTalk — Real-Time Hands-Free Cooking Co-Pilot

<p align="center">
  <img src="app_icon.png" alt="CookTalk Icon" width="120"/>
</p>

<p align="center">
  <a href="https://github.com/openslickofficial/CookTalk"><img src="https://img.shields.io/badge/GitHub-Repository-blue?logo=github" alt="GitHub"/></a>
  <a href="https://drive.google.com/file/d/1vx4A_ec2Gx8idPv7Bbqd7cJ_cQ1lHOWz/view?usp=sharing"><img src="https://img.shields.io/badge/Download-APK-green?logo=android" alt="Download APK"/></a>
  <a href="https://youtube.com/shorts/hlYmq-do5Sc?feature=share"><img src="https://img.shields.io/badge/Watch-Demo%20Video-red?logo=youtube" alt="YouTube Demo"/></a>
</p>

A hands-free, voice-first culinary assistant designed for busy, messy kitchens. Built for the **DataForge × Rime Hackathon** (Track: *"Perceived Response Time"*).

CookTalk eliminates the awkward pause in voice AI by orchestrating an ultra-low-latency pipeline combining **Silero VAD**, **Deepgram STT (`nova-3`)**, **Groq LLM (`qwen/qwen3.8-27b`)**, and **Rime TTS (`coda` / `astra`)** over persistent WebSockets inside **LiveKit WebRTC**.

---

## 🔗 Quick Links

- **🐙 GitHub Repository**: [https://github.com/openslickofficial/CookTalk](https://github.com/openslickofficial/CookTalk)
- **📱 Download Android APK**: [Google Drive](https://drive.google.com/file/d/1vx4A_ec2Gx8idPv7Bbqd7cJ_cQ1lHOWz/view?usp=sharing)
- **🎥 Demo Video**: [Watch on YouTube](https://youtube.com/shorts/hlYmq-do5Sc?feature=share)

---

## 🚀 Quick Deploy (100% FREE)

Deploy the entire CookTalk project for **$0**:

- **Agent Worker**: LiveKit Cloud (1,000 min/month free)
- **Web Frontend**: Cloudflare Pages (unlimited bandwidth)
- **Token Server**: Render.com (750 hours/month free web service)
- **Mobile App**: Direct APK distribution (Android, no Play Store fees)

**Quick Start**: See **[FREE_DEPLOYMENT.md](FREE_DEPLOYMENT.md)** for complete step-by-step guide.

**Architecture**: See **[DEPLOYMENT_ARCHITECTURE.md](DEPLOYMENT_ARCHITECTURE.md)** for detailed component breakdown.

**Total Time**: ~65 minutes | **Total Cost**: $0 ✅

---

## 1. System Architecture

```text
       +-------------------------------------------------------------+
       |               Client (Browser / Test Harness)               |
       +-------------------------------------------------------------+
              ^                                              |
     WebRTC   | Audio Frames                                 | Mic Audio
     Incoming | (PCM 16-bit)                                 | (Opus/WebRTC)
              |                                              v
       +-------------------------------------------------------------+
       |                LiveKit Cloud (SFU / Rooms)                  |
       +-------------------------------------------------------------+
              ^                                              |
              |                                              v
       +-------------------------------------------------------------+
       |             CookTalk Agent Worker (LiveKit Agents)          |
       |                                                             |
       |  1. Silero VAD: Neural voice activity & turn detection      |
       |  2. Deepgram STT (nova-3): Streaming speech-to-text         |
       |  3. Groq LLM (qwen/qwen3.8-27b): Fast streaming tokens      |
       |  4. Rime TTS (coda/astra): WebSocket /ws3 audio chunks      |
       +-------------------------------------------------------------+
              |                                              ^
              | Token Text Stream                            | Audio Chunks
              v                                              | (24 kHz PCM)
       +-------------------------------------------------------------+
       |         Rime Streaming Endpoint (wss://users-ws.rime.ai/ws3)|
       +-------------------------------------------------------------+
```

---

## 1.5 Mobile App Architecture

CookTalk includes a **Flutter mobile app** (Android) providing the same hands-free cooking experience on mobile devices:

**Platform**: Flutter 3.x (Android APK)  
**WebRTC Client**: `livekit_client` Flutter package  
**Token Endpoint**: `https://cooltalk-token-server.onrender.com/token`  
**Distribution**: Direct APK installation (no Google Play Store)  

**Key Features**:
- Same LiveKit WebRTC connection as web frontend
- Voice-controlled recipe navigation and ingredient lookup
- Real-time audio streaming with Rime TTS
- Kitchen timer management with proactive voice alerts
- 60-second connection timeout handling for Render cold starts

**APK Location**: `mobile/build/app/outputs/flutter-apk/app-release.apk`

**Important Note**: First connection after 15 minutes of server idle may take 30-60 seconds due to Render.com free tier cold start. The mobile app includes automatic retry logic and timeout handling for this scenario.

---

## 2. Tech Stack & Third-Party Services

### Tech Stack Table

| Component | Technology | Version | Role |
| :--- | :--- | :--- | :--- |
| **Transport** | LiveKit RTC & Agents | `1.1.17` / `1.8.0` | Real-time WebRTC media rooms, session state |
| **VAD / Turn Detection** | Silero VAD | `1.8.0` plugin | Local neural voice activity and speech endpointing |
| **Speech-to-Text (STT)**| Deepgram `nova-3` | `1.8.0` plugin | Ultra-low latency streaming transcription |
| **Language Model (LLM)**| Groq `qwen/qwen3.8-27b`| OpenAI plugin | Ultra-fast token generation (~100+ tokens/sec) |
| **Text-to-Speech (TTS)**| Rime `coda` / `astra` | `1.8.0` plugin | True WebSocket (`/ws3`) chunked audio synthesis |
| **Backend Framework** | FastAPI / Uvicorn | `0.115.8` | Control baseline server (Phase 1) |
| **Audio Processing** | NumPy / Wave | `2.4.6` | Client harness RMS & peak amplitude analysis |

### Third-Party Services
1. **Rime AI**: Neural low-latency text-to-speech engine (`https://users.rime.ai` and `wss://users-ws.rime.ai/ws3`).
2. **LiveKit Cloud**: Managed WebRTC SFU infrastructure and agent dispatch.
3. **Deepgram**: Streaming audio transcription (`api.deepgram.com`).
4. **Groq**: LPU inference engine for rapid LLM completion (`api.groq.com`).

---

## 3. Verified Rime Configuration

| Setting | Verified Value | Description |
| :--- | :--- | :--- |
| **Model** | `coda` | Rime's flagship conversational model |
| **Speaker / Voice** | `astra` | Expressive, natural starter voice |
| **Language** | `en` (English) | Model native |
| **Transport** | `WebSocket` (`use_websocket=True`) | Direct low-latency socket streaming |
| **Endpoint** | `wss://users-ws.rime.ai/ws3` | Binary chunked audio streaming |
| **Audio Output** | PCM 16-bit, 24,000 Hz, mono | Streamed directly into LiveKit audio tracks |

---

## 4. Empirical Performance Summary

CookTalk is **~8% faster end-to-end (5,859.3 ms vs. 6,335.6 ms naive HTTP baseline)** across realistic, tool-assisted culinary turns in the kitchen. Behind this overall speedup is a **9.27x component-level synthesis speedup (386.0 ms vs. 3,578.0 ms TTFB, median from 24 clean trials in `agent/bench/demo_script_benchmark_results.jsonl`)** that eliminated Rime TTS as the pipeline bottleneck, shifting the remaining latency to upstream LLM reasoning and safety-critical VAD endpointing.

Detailed evidence, procedures, diagnostic traces, and trial breakdowns are documented in [`RIME_EVIDENCE.md`](./RIME_EVIDENCE.md) and [`docs/timeout-diagnosis.md`](./docs/timeout-diagnosis.md).

### A. Headline Performance Comparison Across All Pipeline Phases

| Metric | Phase 1: Naive HTTP (`/control`) | Phase 2: Server Proxy (`/agent`) | Phase 3.8: Rapid Burst (`n=30`) | Phase 6 Part A: Idle Sweep (`n=24`) | Phase 6.9: Final Demo Script Benchmark |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TTS Time-to-First-Audio (TTFB)** | 3,578.0 ms (Full WAV) | **389.1 ms** (First Chunk) | **506.2 ms** (First Chunk) | **388.2 ms** (`WarmRimeTTS` 60s idle) | **386.0 ms** (Median, $n=24$ clean trials from `demo_script_benchmark_results.jsonl`) |
| **Client First-Audio Latency (Median)**| 6,335.6 ms | **1,767.2 ms** (Server Sum) | **4,512.7 ms** | **4,238.5 ms** (20s gap) | **4,740.7 ms** (Spoken Ack first sound) |
| **Client Substantive Answer (Median)** | 6,335.6 ms | **1,767.2 ms** (Server Sum) | **4,512.7 ms** | **4,260.4 ms** | **4,924.4 ms** (Grounded culinary reply) |
| **TTS Component Speedup** | *Baseline* | **9.19x faster** | **7.07x faster** | **9.22x faster** | **9.27x faster** |
| **Call-Level Completion Rate** | 100% (Synchronous) | Untested under WebRTC | **100.0% (30 / 30 trials)** | **100.0% (24 / 24 trials)** | **100.0% (25 / 25 trials)** |
| **State-Isolation & Desync Pass Rate** | Untested | Untested | Untested | Untested | **100.0% (Zero cross-turn drift)** |
| **Rate-Limit Handling** | N/A | N/A | Dynamic backoff | N/A | **Graceful stop at quota boundary** |


### B. Controlled Idle Sweep: Pre-Fix vs. Post-Fix (`WarmRimeTTS`)

To resolve idle socket teardown, we measured Rime TTS TTFB and client latency across 8 gap durations (2s to 60s, 3 trials each = 24 trials):

| Idle Gap Duration | Pre-Fix Rime TTFB (Median) | Post-Fix Rime TTFB (`WarmRimeTTS`) | TTFB Improvement | Post-Fix Client Latency (Median) |
| :--- | :--- | :--- | :--- | :--- |
| **2s** | 393.0 ms | **382.8 ms** | -10.2 ms | 4,739.6 ms |
| **5s** | 423.2 ms | **404.5 ms** | -18.7 ms | 4,569.5 ms |
| **10s** | 367.5 ms | **399.2 ms** | +31.7 ms | 4,280.0 ms |
| **15s** | 426.8 ms | **390.3 ms** | -36.5 ms | 4,179.7 ms |
| **20s** | 367.3 ms | **390.7 ms** | +23.4 ms | 4,238.5 ms |
| **30s** | 1,481.9 ms | **395.1 ms** | **-1,086.8 ms (73.3% faster)** | **4,260.4 ms** |
| **45s** | 1,514.9 ms | **439.8 ms** | **-1,075.1 ms (71.0% faster)** | **4,179.5 ms** |
| **60s** | 1,568.6 ms | **388.2 ms** | **-1,180.4 ms (75.3% faster)** | **4,989.9 ms** |

### C. Tool Acknowledgment Latency Masking (Phase 6.9 Reconciled)

In a grounded voice co-pilot, ~80% of interactions require tools (`get_ingredient_quantity`, `suggest_substitution`, `next_step`). Under naive tool routing, the cook experiences a prolonged silence while the LLM completes two passes. CookTalk fires an **instant spoken acknowledgment** (`speak_acknowledgment`) the millisecond a tool is dispatched:

- **Server-Side Ack Latency**: **875.0 ms** median after EOU (**892.5 ms** mean across clean trials).
- **Client-Perceived First Sound**: **4,740.7 ms** median wall-clock from user speech end under the full WebRTC audio loop (including WAV trailing silence, Silero VAD endpointing, LLM tool classification, Rime synthesis, and WebRTC jitter playout).
- **Substantive Answer Delivery**: **4,924.4 ms** median client-perceived latency.
- **Total Turn Duration**: **5,859.3 ms** median (reflecting concise 1-2 sentence speech playout under 25 words with multi-item conversational truncation).
- **Rime TTS Component TTFB**: **386.0 ms** over WebSocket (`/ws3`) — delivering a **9.27x component speedup** over naive HTTP baseline.

---

## 5. Reliability Hardening & Failure Behavior

Across Phases 3.5 through 6.9, we diagnosed and eliminated harness timeout vulnerabilities, upstream rate limit failures, and idle socket drops:

1. **VAD Trailing Silence & Endpointing (Phase 3.5)**:
   - **Trailing Silence Starvation**: Padded all fixture WAVs with 800ms silence and streamed continuous background silence frames to prevent VAD buffer starvation.
   - **VAD Pause Sensitivity**: Increased `min_endpointing_delay` to 0.6s to eliminate mid-sentence cut-offs on complex queries.
2. **Groq Context Sanitization & Preemption (Phase 3.6)**:
   - **Consecutive User Pathology**: Implemented `sanitize_chat_context` to collapse consecutive user turns, preventing empty LLM streaming completions.
   - **Preemption Storms**: Disabled speculative generation (`preemptive_generation=False`) to avoid burning tokens on canceled streams.
3. **Dynamic Rate-Limit Backoff (Phase 3.8)**:
   - Implemented `DynamicGroqConnectOptions` with `parse_retry_after(error)`: parses Groq's exact reset time (`try again in Xs`) and sleeps dynamically (capped at 3.0s), raising answered turns from 76.7% to 90.0%.
4. **Active Connection Warming (`WarmRimeTTS`, Phase 6)**:
   - Configured `max_session_duration = 12.0s` on LiveKit's `ConnectionPool` and background keepalive prewarming, eliminating the 1.1s idle cold-handshake penalty across all idle durations up to 60 seconds (73–75% TTFB speedup).
5. **Tool Acknowledgment Latency Masking (Phase 6.6–6.9)**:
   - Built `speak_acknowledgment` on tool dispatch via Rime `/ws3`, delivering first audio in 875.0 ms median after EOU (4,740.7 ms client wall-clock) to mask dual-pass LLM reasoning.
6. **Prompt-Enforced Response Conciseness (Phase 6.9)**:
   - Enforced 1-2 sentence responses and conversational multi-item truncation in `agent.py`, dropping median turn duration to 5,859.3 ms.
7. **Grounded Culinary Features (Phase 4)**:
   - Grounded recipe knowledge (`agent/recipes.json`) covering French Scrambled Eggs, Cacio e Pepe, and Reverse-Sear Ribeye Steak.
   - 17 asynchronous LiveKit function tools including step navigation, ingredient queries, substitutions, allergy checks, multi-timer support, and session management (NOTE: pause_timer/resume_timer NOT implemented).
   - Proactive WebRTC timer countdown alerts generated via Rime TTS `copilot.session.say(...)` without user prompting.
8. **Audible Fallback Behavior**:
   - If Rime is unreachable or credentials fail, `FallbackAdapter` seamlessly switches to `LocalFallbackTTS` and speaks a pre-recorded emergency audio notice over WebRTC in **1,256.6 ms**.
   - If LLM retries exhaust under free-tier quota limits (e.g. Groq 200k TPD ceiling), `RetryingGroqStream` injects a clear voice apology notice over WebRTC rather than freezing silently.


---

## 6. Setup & Reproduction Instructions

### A. Environment Configuration
Copy `.env.example` to `.env` at the repository root and fill in your API keys:
```bash
LIVEKIT_URL=wss://your-subdomain.livekit.cloud
LIVEKIT_API_KEY=your_livekit_api_key
LIVEKIT_API_SECRET=your_livekit_api_secret
DEEPGRAM_API_KEY=your_deepgram_key
GROQ_API_KEY=your_groq_key
RIME_API_KEY=your_rime_key
```

### B. Running the Phase 1 Baseline (`/control`)
```powershell
cd control
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
python server.py
# In a separate terminal:
python run_baseline.py
```

### C. Running the Real-Time Streaming Agent (`/agent`)
```powershell
cd agent
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
python agent.py dev
```

### D. Running the Web Frontend & Token Server (`/web`)
CookTalk includes a custom kitchen-ready web application featuring live waveform visualizers, real-time Latency HUD, step-by-step recipe card navigation, and hands-free timer controls:

```powershell
# 1. Start the Token & Recipe Server (Port 8000)
cd web
..\agent\venv\Scripts\python token_server.py

# 2. In a separate terminal, start the Vite Dev Server (Port 5173)
cd web
npm install
npm run dev
```
*Open `http://127.0.0.1:5173` in any modern browser, click "Start Cooking Session", and talk hands-free.*

### E. Running the Automated Benchmark Harness (`/agent/bench`)
```powershell
cd agent
# 1. Synthesize question audio fixtures with trailing silence (run once)
python bench/generate_fixtures.py

# 2. Run the post-fix controlled idle sweep (2s to 60s gaps)
python bench/sweep_idle_duration_warmed.py

# 3. Run the 30-trial human-paced kitchen benchmark
python bench/bench_runner_human_paced.py

# 4. Run the deliberate Rime failure fallback test
python bench/test_rime_failure.py

# 5. Run the Phase 4 culinary acceptance test suite (7 voice scenarios)
python bench/run_acceptance_test.py
```

---

## 7. Organizer Preflight Check & Compliance Audit

- **Organizer Script Status**: No automated preflight script was supplied in the hackathon repository.
- **Manual Verification Checklist for Evaluators**:
  1. **Eligibility Rules**: Confirmed. Voice synthesis is integral to CookTalk's core user experience; Rime TTS (`coda` / `astra`) is the sole speech engine; no static screens or mock workflows.
  2. **Secret Hygiene**: Full git commit history audited for API keys (`gsk_`, `sk-`, `dg-`, `livekit-`). Zero secrets leaked.
  3. **Live Rime Voice Catalog**: Verified via `https://users.rime.ai/data/voices/all-v2.json` (HTTP 200) that `astra` is an active flagship voice among 162 Coda English voices.
  4. **Active Provider Observability**: The Web Frontend Latency HUD actively displays the live synthesis engine (`Rime coda / astra (WebSocket /ws3)`) along with live STT and LLM metrics.

---

## 8. Live vs. Precomputed Statement

> **Every benchmark number, latency metric, and timing log in this repository was measured live against real production endpoints.**
> 
> No latency values are precomputed, hardcoded, or simulated. All 30 trials in [`agent/bench/client_perceived_human_paced.jsonl`](./agent/bench/client_perceived_human_paced.jsonl), the 24 trials in [`agent/bench/idle_sweep_results_warmed.jsonl`](./agent/bench/idle_sweep_results_warmed.jsonl), and baseline runs in [`control/baseline_results.jsonl`](./control/baseline_results.jsonl) were recorded directly over active network connections to LiveKit Cloud, Deepgram, Groq, and Rime.

---

## 9. Known Limitations

- **Upstream Rate-Limit Variance (P95 vs. Median)**: First-audio latency exhibits a wide gap between median (4,740.7 ms) and P95 (10,306.9 ms) exclusively driven by upstream Groq free-tier 7,000 ITPM rate limits triggering backoff retries (e.g., Trial 16 incurred 9,360 ms LLM delay during backoff), while Rime TTS synthesis remained constant at ~386 ms.
- **Benchmark Trial Exclusion**: Exactly 1 of 25 trials (Trial 13) was marked incomplete by the harness validation guard because detected audio arrived at 237.9 ms (< 400 ms validity floor) due to residual audio packet bleed during WebRTC track initialization, properly excluding it from latency calculations to maintain sample purity.
- **Geographic Network Overhead**: The benchmark client and agent worker executed in the India South region, communicating with US-based LLM, STT, and TTS endpoints, contributing a baseline ~150–250 ms round-trip network transit time.
- **Upstream Daily Quotas**: Groq free-tier accounts enforce a 7,000 ITPM limit and a 200,000 Tokens Per Day (TPD) ceiling. Under extensive multi-round testing, exceeding the daily token limit triggers the graceful audible fallback notice.
- **Client-Side Playout Delay**: True client-perceived audio includes WebRTC track negotiation and client-side jitter buffer latency (~1.2s playout buffering), making client-perceived time higher than the raw internal server-side proxy (~2.0s).
- **Synthetic Caller**: Automated benchmarks transmit pre-recorded 16 kHz audio without ambient kitchen noises (sizzling oil, exhaust fan background noise).

---

## 10. AI-Assistance Disclosure

In compliance with hackathon guidelines:

- **Phase 1 (Control Baseline)**:
  - *AI-Assisted*: Scaffolding FastAPI server, creating HTML audio recorder, writing baseline benchmarking script.
  - *Human-Verified*: Validated Rime HTTP API schema against live docs, checked audio playback, verified latency calculations.
- **Phase 2 (Streaming Pipeline)**:
  - *AI-Assisted*: Writing LiveKit agent worker script, configuring Groq OpenAI-compatible client, setting up Rime WebSocket plugin.
  - *Human-Verified*: Resolved live model availability (`qwen/qwen3.8-27b`), verified plugin parameter `use_websocket=True`, conducted live voice interaction over LiveKit Agents Playground.
- **Phase 3 (Latency Harness & Evidence Artifacts)**:
  - *AI-Assisted*: Writing client-side benchmark runner using `livekit.rtc`, generating audio fixture synthesis script, statistical analysis.
  - *Human-Verified*: Executed 30 live WebRTC trials, diagnosed VAD edge cases on long utterances, verified failure exception behavior.
- **Phase 3.5 (VAD & Silence Hardening)**:
  - *AI-Assisted*: Diagnosing trailing silence starvation and VAD pause sensitivity, building `LocalFallbackTTS` and `FallbackAdapter`, instrumenting diagnostic stage logging.
  - *Human-Verified*: Re-ran 30-trial benchmark, verified 100% success on 9.6s complex query (Q6), confirmed user-facing audible voice fallback under simulated outage.
- **Phase 3.6 (LLM Layer Hardening & Response-Length Independence)**:
  - *AI-Assisted*: Diagnosed Groq empty completions on consecutive user turns and speculative preemption abort storms, built `RetryingGroqLLM` and `sanitize_chat_context`, fixed `-1000ms` logging sentinel.
  - *Human-Verified*: Achieved 30/30 (100.0%) benchmark completion reliability with zero timeouts, verified balanced stress case (+58.5ms difference between short and long questions).
- **Phase 3.8 (Rate-Limit Backoff Optimization & Evidence Integrity)**:
  - *AI-Assisted*: Implemented `DynamicGroqConnectOptions` parsing upstream `Retry-After` reset hints, configured dynamic backoff ceiling for conversational voice flow, separated call completion from question answering in logs and reports.
  - *Human-Verified*: Validated live Groq model catalog (`docs/groq-models-verified.json`), re-ran 30-trial benchmark verifying 100% call stability (0 hangs), 90.0% question answered rate (27/30), and 10.0% fallback apology (3/30).
- **Phase 4 (Product Work: Culinary Persona, Function Calling & Acceptance Verification)**:
  - *AI-Assisted*: Structured culinary database (`recipes.json`), built stateful `CookingCoPilot` with 17 LiveKit asynchronous function tools (pause_timer/resume_timer not implemented), built proactive WebRTC timer alert via Rime TTS `copilot.session.say(...)`, created automated acceptance test runner (`run_acceptance_test.py`).
  - *Human-Verified*: Executed 7 live voice acceptance scenarios against LiveKit Cloud WebRTC, verified 7 / 7 (100%) PASS with verbatim grounded answers, confirmed proactive spoken timer alert over WebRTC audio track, spot-checked pipeline latency showing zero tool-calling regression.
- **Phase 5 (Custom Web Frontend & Smoke Verification)**:
  - *AI-Assisted*: Scaffolding React/Vite web application with Lucide icons and Tailwind-like styling, implementing LiveKit WebRTC client hooks, live audio waveform visualizer, real-time Latency HUD with component breakdown, recipe card navigator, and active kitchen timer widget; creating `web/token_server.py`.
  - *Human-Verified*: Executed end-to-end frontend smoke test (`smoke_test_frontend_session.py`), verified live token generation, WebRTC room connection, voice round-trip, and proactive timer audio playback.
- **Phase 6 (Controlled Idle Sweep, Keepalive Architecture & Final Benchmark)**:
  - *AI-Assisted*: Created controlled idle sweep harness (`sweep_idle_duration.py`), diagnosed 20–30s remote WebSocket idle drop threshold, engineered `WarmRimeTTS` with active connection pool recycling and background prewarming, executed post-fix sweep and final 30-trial human-paced benchmark, performed repository-wide git secret audit.
  - *Human-Verified*: Verified 73–75% TTFB speedup across 30s–60s idle gaps, confirmed 0 secrets in git history, verified live Rime voice catalog endpoint, audited documentation consistency.




---

## Implementation Notes

### cook_history Dual-Write Pattern (INTENTIONAL)

The `cook_history` table is written at **two distinct locations** with different triggers. This is **intentional** to support both discovery and session tracking:

1. **Dish View/Tap** (`mobile/lib/screens/home_screen.dart:680, 881, 1174`)
   - Trigger: User taps dish card to preview recipe
   - Purpose: Track "Recently Viewed" for discovery/navigation
   - Alias: `recordDishViewedInAI()` → `recordCookHistory()`

2. **Session Start** (`mobile/lib/main.dart:1009`)
   - Trigger: User starts live cooking session (InSessionScreen initState)
   - Purpose: Mark dish as "Cooked before" + populate cook_history for ranking
   - Implementation: `await SupabaseService.instance.recordCookHistory(widget.initialRecipe.id);`

**Deduplication**: `userList.removeWhere((h) => h.dishId == dishId)` in `recordCookHistory()` prevents duplicates.

**Database**: Supabase `upsert` is idempotent based on `(user_id, dish_id)` composite.

**Rationale**: 
- Viewing a recipe != cooking it, but both are useful signals
- "Recently Viewed" shows discovery patterns
- Session start definitively marks intent to cook
- Same method ensures consistent timestamp updates
