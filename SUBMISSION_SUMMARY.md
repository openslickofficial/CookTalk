# 🚀 CookTalk Hackathon Submission — Executive Summary

**Date**: September 8, 2026  
**Track**: DataForge × Rime Hackathon — Perceived Response Time  
**Submitter**: Subhajit Mandal  

---

## 📊 **PROJECT OVERVIEW**

**CookTalk** is a hands-free, voice-first cooking assistant that eliminates the "awkward pause" in voice AI through ultra-low-latency streaming orchestration.

### The Problem
Traditional voice assistants fail in the kitchen because cooks can't touch screens with messy hands, and 6-7 second response delays feel like an eternity when you're mid-recipe.

### The Solution
CookTalk achieves **5.8-second end-to-end conversational turns** (vs. 6.3s naive baseline) through:
- **9.27x faster TTS** via Rime WebSocket streaming (386ms vs. 3,578ms)
- **Instant acknowledgments** during tool calls (875ms) to eliminate perceived silence
- **Connection warming** that prevents idle timeout penalties up to 60 seconds

---

## 🎯 **KEY ACHIEVEMENTS**

### 1. Performance
| Metric | Baseline | CookTalk | Improvement |
|--------|----------|----------|-------------|
| **TTS TTFB** | 3,578ms | 386ms | **9.27x faster** |
| **Idle 60s Gap TTFB** | 1,569ms | 388ms | **75% faster** |
| **Tool Acknowledgment** | Silent wait | 875ms spoken | **Perceived latency eliminated** |
| **End-to-End Turn** | 6,336ms | 5,859ms | **8% faster** |
| **Completion Rate** | 100% | 100% | **Rock solid** |

### 2. Production Deployment ($0 Cost)
- ✅ **Agent**: LiveKit Cloud (Mumbai region, 24/7 uptime)
- ✅ **Token Server**: Render.com (free tier with cold start handling)
- ✅ **Mobile App**: Flutter APK with 60s timeout for cold starts
- ✅ **Web Frontend**: Cloudflare Pages (development ready)

### 3. Engineering Excellence
- **Battle-tested**: 30+ benchmark trials with zero hangs or failures
- **Graceful degradation**: Audible 1.2s fallback notice on Rime unavailability
- **Honest documentation**: RIME_EVIDENCE.md shows real-world challenges and solutions
- **Clean codebase**: No exposed credentials, comprehensive .gitignore

---

## 🔬 **RIME INTEGRATION SPECIFICS**

### Configuration
- **Model**: `coda` (Rime's flagship conversational model)
- **Voice**: `astra` (expressive, natural starter voice)
- **Language**: `en` (English)
- **Transport**: WebSocket (`/ws3`) for true streaming
- **Endpoint**: `wss://users-ws.rime.ai/ws3`
- **Audio**: PCM 16-bit, 24kHz mono → LiveKit WebRTC

### Core Innovation
Rime WebSocket streaming is **not just faster** — it's architecturally different:
1. **Eliminates buffering**: Audio chunks stream as generated, no monolithic WAV wait
2. **Connection keepalive**: `WarmRimeTTS` pool prevents idle socket teardowns
3. **Immediate feedback**: Sub-400ms TTFB enables instant spoken acknowledgments during tool calls

### Why This Matters
In culinary voice UX, tool calls (ingredients, substitutions, steps) represent ~80% of interactions. Traditional pipelines leave users in awkward silence during dual LLM passes. CookTalk speaks immediately ("Checking ingredients...") in 875ms, then delivers the substantive answer once ready — **perceived latency is eliminated**.

---

## 📹 **DEMO SURFACES**

### Web Frontend (Development)
- Full Latency HUD showing component-level timings
- Audio visualizer for live waveform feedback
- Recipe step cards with timer controls
- Ideal for technical demonstration of streaming pipeline

### Mobile App (Production)
- Flutter Android APK for realistic kitchen usage
- Hands-free voice control (no screen touches)
- Automatic retry and timeout handling
- Demonstrates true "dirty hands" use case

**Demo Video** (pending): Will showcase both surfaces per `docs/demo-script.md`

---

## 📁 **REPOSITORY STRUCTURE**

```
cooltalk/
├── agent/                  # LiveKit agent worker (Python)
│   ├── agent.py           # Main agent with WarmRimeTTS pool
│   ├── bench/             # Benchmark harnesses & acceptance tests
│   └── recipes.json       # Recipe database (350+ dishes)
├── web/                   # Vue 3 web frontend
│   ├── src/               # Frontend components
│   └── token_server.py    # FastAPI token generation
├── mobile/                # Flutter mobile app (Android)
│   ├── lib/               # Dart source code
│   └── build/app/outputs/ # Compiled APK
├── docs/                  # Technical documentation
│   ├── demo-script.md     # Video recording guide
│   ├── acceptance-test-transcripts.md
│   └── rime-api-notes.md
├── README.md              # Comprehensive setup & architecture
├── RIME_EVIDENCE.md       # Empirical performance evidence
├── FREE_DEPLOYMENT.md     # $0 deployment guide
└── FINAL_SUBMISSION_CHECKLIST.md  # This document's companion
```

---

## ✅ **SUBMISSION CHECKLIST STATUS**

| Item | Status | Notes |
|------|--------|-------|
| Demo Video | ⚠️ **PENDING** | Script ready, need to record |
| Source Code | ✅ **READY** | Public repo, clean, documented |
| README.md | ✅ **UPDATED** | Fixed deployment info, added mobile section |
| RIME_EVIDENCE.md | ✅ **EXCELLENT** | Comprehensive evidence with honest limitations |
| .env.example | ✅ **VERIFIED** | Placeholders only |
| Credential Safety | ✅ **CLEAN** | All secrets in .gitignore |
| Working Demo | ✅ **DEPLOYED** | Agent + token server + mobile APK all operational |

---

## 🎬 **DEMO VIDEO PLAN** (4-5 minutes)

### Beat 1: Problem (35s)
"When you're searing a steak with oily hands, you can't touch a screen. Voice AI should help, but 6-7 second pauses feel like an eternity..."

### Beat 2: Normal Flow (50s)
Live demonstration:
- "What ingredients do I need for Cacio e Pepe?"
- "What if I don't have Pecorino Romano?"
- "Set a timer for 20 seconds"

Show instant acknowledgments and streaming responses.

### Beat 3: Hard Engineering Problem (55s)
Explain the 4-tier latency optimization:
1. WebSocket streaming (9.27x TTS speedup)
2. Connection warming (75% idle speedup)
3. Spoken acknowledgments (875ms perceived latency masking)
4. Prompt truncation (5.9s turn duration)

Show Latency HUD with live measurements.

### Beat 4: Stress Test (40s)
Complex multi-clause query:
"I have ribeye steak and want to understand carryover cooking science..."

Show latency stays predictable (+589ms vs. short queries).

### Beat 5: Proactive Timer (40s)
Set 20-second timer, show autonomous voice alert when finished (no user input).

### Beat 6: Failure Case (30s)
Simulate Rime unavailability, show graceful 1.2s audible fallback:
"Sorry, I'm having trouble with speech synthesis..."

### Beat 7: Results (20s)
Performance comparison table showing 9.27x component speedup and 8% end-to-end improvement.

---

## 🏆 **WHY COOKTALK SHOULD WIN**

### 1. **Real-World Engineering**
Not just "run the benchmark" — we solved actual production problems:
- Idle socket teardowns
- Tool call acknowledgment latency
- Render cold start handling
- Graceful failure modes

### 2. **Honest Performance Reporting**
RIME_EVIDENCE.md doesn't hide challenges:
- Shows where upstream LLM reasoning dominates total latency
- Documents the 60s idle timeout problem AND the fix
- Explains why 8% end-to-end improvement represents a 9.27x component-level win

### 3. **Production-Ready Deployment**
- Fully deployed for $0 (no "localhost only" demo)
- Mobile app handles real kitchen use case
- 100% completion rate across stress testing
- Graceful degradation on provider failures

### 4. **User-Centric Design**
- Instant spoken acknowledgments during tool calls
- Proactive voice alerts for timers
- Concise conversational responses (<25 words)
- True "dirty hands" hands-free experience

### 5. **Comprehensive Documentation**
- README: Architecture, setup, third-party services
- RIME_EVIDENCE: Empirical performance with reproduction commands
- Demo script: 7-beat video guide
- Acceptance tests: Automated verification harness

---

## 📞 **QUICK START FOR JUDGES**

### Option A: Test Mobile App
1. Download APK: `mobile/build/app/outputs/flutter-apk/app-release.apk`
2. Install on Android device (allow "Unknown Sources")
3. Launch CookTalk, tap "Start Cooking Assistant"
4. Wait 30-60s for first connection (Render cold start)
5. Say: "What ingredients do I need for pancakes?"
6. Hear instant acknowledgment + streaming response

### Option B: Run Local Agent
```powershell
# Clone repo
git clone <repo-url>
cd cooltalk

# Setup agent
cd agent
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt

# Add API keys to .env (copy from .env.example)
# DEEPGRAM_API_KEY, GROQ_API_KEY, RIME_API_KEY, LIVEKIT_*

# Run agent
python agent.py dev
```

### Option C: Review Evidence
1. Read `RIME_EVIDENCE.md` for detailed performance analysis
2. Check `docs/demo-script.md` for expected behavior
3. Review `README.md` for architecture details

---

## 🔗 **IMPORTANT LINKS**

- **Production Agent**: `wss://cooltalk-9ik3u4wt.livekit.cloud` (LiveKit Cloud, Region: ap-south Mumbai)
- **Token Server**: `https://cooltalk-token-server.onrender.com`
- **Source Repo**: [Link to be added before submission]
- **Demo Video**: [Link to be added after recording]

---

## 📧 **CONTACT**

**Name**: Subhajit Mandal  
**Email**: [Email from submission form]  
**GitHub**: [GitHub username from submission form]  

---

## 🙏 **ACKNOWLEDGMENTS**

Built with:
- **Rime AI**: Low-latency TTS (the star of the show)
- **LiveKit**: WebRTC infrastructure and agent SDK
- **Deepgram**: Ultra-fast STT
- **Groq**: Blazing LLM inference
- **DataForge**: For organizing this amazing hackathon

---

**Last Updated**: September 8, 2026  
**Status**: Ready for final demo recording and submission  
**Total Development Time**: 6 phases, 30+ benchmark iterations, 100+ commits  
**Lines of Code**: ~3,500 (agent) + ~2,000 (web) + ~1,500 (mobile) + ~2,000 (docs/tests)
