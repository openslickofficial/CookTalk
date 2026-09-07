# CookTalk — Demo Video Script & Walkthrough Guide

**Target Video Runtime**: ~4 minutes 30 seconds  
**Track**: Perceived Response Time (DataForge × Rime Hackathon)  
**Presenter**: Solo / Pair Engineering Demo  
**Screen Setup**: Split screen or full view showing the CookTalk Web App (`http://127.0.0.1:5173`) with live audio visualizer, Latency HUD, step cards, and timer controls, alongside terminal logs / benchmark artifacts.

---

## Video Beat Breakdown

| Beat | Timestamp | Duration | Section Title | Visual Focus | Spoken / Audio Action |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | `0:00 – 0:35` | 35s | **The Problem: The Awkward Kitchen Pause** | Web App Home / Kitchen context | Introduce CookTalk problem space and voice latency bottleneck |
| **2** | `0:35 – 1:25` | 50s | **Core Culinary Flow: Grounded Voice Co-Pilot** | Live Web App with Cacio e Pepe step cards | Hands-free recipe traversal, ingredient quantity, substitution |
| **3** | `1:25 – 2:20` | 55s | **The Hard Voice Engineering Story** | Latency HUD & Architecture diagram | HTTP vs. WebSocket `/ws3`, Rime TTFB, connection keepalive |
| **4** | `2:20 – 3:00` | 40s | **Stress Test: Multi-Clause Complex Query** | Latency HUD in action during long question | Measuring response latency under heavy prompt load |
| **5** | `3:00 – 3:40` | 40s | **Proactive Feature: Hands-Free Timer Alert** | Kitchen Timer Card countdown & waveform | Autonomous server-triggered spoken audio alert |
| **6** | `3:40 – 4:10` | 30s | **Failure Transparency: Deliberate Fallback** | Fallback test log & audio playback | Graceful 1.2s audible apology under outage simulation |
| **7** | `4:10 – 4:30` | 20s | **Summary & Verification** | Performance Comparison Table | Final verdict, reproducibility, and closing |

---

## Detailed Script & Presenter Cues

### Beat 1: The Problem — The Awkward Kitchen Pause (`0:00 – 0:35`)
- **Visual**: Show the CookTalk web application interface on `http://127.0.0.1:5173`. Highlight the active status badge (`Rime coda / astra (WebSocket /ws3)`), audio waveform visualizer, and recipe selector.
- **Presenter (Voiceover)**:
  > *"When you’re in the middle of searing a ribeye or emulsifying a delicate sauce, your hands are covered in oil, flour, or raw egg. You can’t touch a smartphone screen or a keyboard. Voice AI should be the perfect kitchen companion.*
  > 
  > *But traditional voice assistants fail in the kitchen for one critical reason: the awkward pause. In a naive pipeline, you ask a question, wait for transcription, wait for the entire paragraph of text to generate, and then wait 3.5 seconds for a monolithic TTS server to synthesize an entire WAV file before hearing a single sound. That 6-to-7 second silence feels like an eternity.*
  > 
  > *This is CookTalk — a voice-first culinary co-pilot engineered to eliminate that conversational lag."*

---

### Beat 2: Core Culinary Flow — Grounded Voice Co-Pilot (`0:35 – 1:25`)
- **Visual**: Click **"Start Cooking Session"**. The browser requests microphone permission and connects instantly over WebRTC to LiveKit Cloud. Select the recipe **"Classic Roman Cacio e Pepe"**. The step card updates visually to Step 1.
- **Action / Spoken Interaction**:
  - **User**: *"CookTalk, what ingredients do I need for Cacio e Pepe?"*
  - **CookTalk (Immediate Acknowledgment via Rime `astra`)**: *"Checking the ingredients list for you."* *(Spoken in ~875 ms after EOU)*
  - **CookTalk (Substantive Answer)**: *"For Cacio e Pepe, you'll need spaghetti, pecorino, and black pepper, plus a couple pantry items. Want the rest?"*
  - **User**: *"What if I don't have Pecorino Romano?"*
  - **CookTalk (Immediate Acknowledgment)**: *"Looking up what you can swap in."*
  - **CookTalk (Substantive Answer)**: *"You can use a 50/50 mix of Parmigiano-Reggiano and Grana Padano for a similar salty, nutty kick."*
  - **User**: *"Got it. What's the next step?"*
  - **CookTalk (Immediate Acknowledgment)**: *"Getting the next step."*
  - **CookTalk (Substantive Answer)**: *"Toast cracked black pepper in a wide dry skillet over medium heat for one minute until fragrant."*
- **Presenter (Voiceover)**:
  > *"Notice how natural that feels. First, every tool response begins with an immediate spoken acknowledgment — the cook is never left in silence wondering if the assistant heard them. Second, answers are punchy and conversational (under 20-25 words), offering to expand rather than reading long monologues to someone with dirty hands. Third, speech output streams directly into WebRTC via Rime's `/ws3` WebSocket endpoint without waiting for the full sentence to finish generating."*

---

### Beat 3: The Four-Tier Latency Engineering Story (`1:25 – 2:20`)
- **Visual**: Focus on the **Latency HUD** on the right side of the screen. Show the live breakdown:
  - VAD / Turn Endpointing: `~600 ms`
  - STT Delay: `~250 ms` (Deepgram `nova-3`)
  - LLM TTFT: `~650 – 800 ms` (Groq `qwen/qwen3.8-27b`)
  - TTS TTFB: `~386 ms` (Rime `coda`/`astra` via `/ws3`)
  - Server Ack Latency: `~875 ms` (EOU to ack dispatch)
  - Display the comparison chart from `RIME_EVIDENCE.md`.
- **Presenter (Voiceover)**:
  > *"How did we achieve this? In our Phase 1 HTTP baseline, generating audio required 3,578 ms for TTS alone, pushing client-perceived latency to 6.3 seconds.*
  > 
  > *In CookTalk, we stream directly to Rime’s `/ws3` binary WebSocket endpoint inside a LiveKit agent worker. Rime returns the first audio chunk in just 386 milliseconds — a **9.27x component speedup**.*
  > 
  > *Crucially, we tackled two real-world hurdles that naive benchmarks ignore:*
  > 
  > *First, idle kitchen pauses: when a cook steps away for 20 to 30 seconds, remote WebSockets tear down, causing a 1.1-second cold-start delay. Our `WarmRimeTTS` pool manager actively prewarms idle connections, keeping TTFB flat at ~386ms across all gaps up to 60 seconds — a 73–75% speedup.*
  > 
  > *Second, tool calls: checking ingredients or steps requires two LLM passes, which would normally create an awkward silence. CookTalk fires an immediate spoken acknowledgment the instant a tool dispatches in ~875ms after EOU, keeping the cook actively engaged while Rime's sub-400ms streaming TTS prepares the substantive answer."*

---

### Beat 4: Stress Test — Multi-Clause Complex Query (`2:20 – 3:00`)
- **Visual**: Show the Latency HUD ready to capture live timing.
- **Action / Spoken Interaction**:
  - **User**: *"I have some aged ribeye steak in the fridge and want to make sure the internal temperature doesn't overshoot medium rare. Can you explain the science of carryover cooking and what temperature I should pull it off the heat?"*
  - **CookTalk**: *"For medium rare, pull the steak when the internal temperature reaches 125 to 130 degrees Fahrenheit. During resting, residual heat continues cooking the center, raising the internal temperature by another 5 to 10 degrees."*
- **Presenter (Voiceover)**:
  > *"Watch the Latency HUD. That was a long, complex multi-clause question. Under naive VAD, natural pauses mid-sentence would cause premature cut-offs. We tuned Silero endpointing to 600ms and sanitized consecutive chat context.*
  > 
  > *Across 30 benchmarked trials, long multi-clause questions added just +589 milliseconds over short single-clause queries. That represents predictable, modest scaling with prompt length, not conversational stalls."*

---


### Beat 5: Proactive Feature — Hands-Free Kitchen Timer Alert (`3:00 – 3:40`)
- **Visual**: The kitchen timer widget in the web application.
- **Action / Spoken Interaction**:
  - **User**: *"Set a timer for 20 seconds for the pepper toast."*
  - **CookTalk**: *"Starting a 20-second timer for pepper toast now."*
- **Visual**: The timer countdown card animates live: `20s... 15s... 5s... 0s`.
- **System Event (No user input)**:
  - Server timer fires asynchronously. The LiveKit agent worker uses `copilot.session.say(...)` to synthesize and stream a proactive voice alert over WebRTC.
  - **CookTalk (Proactive Voice)**: *"Time's up! Your 20-second timer for pepper toast is finished."*
- **Presenter (Voiceover)**:
  > *"Notice what just happened: the agent spoke proactively without any user question or wake-word. It synthesized the notification on the fly using Rime TTS over WebRTC, alerting the cook the instant the toast phase completed."*

---

### Beat 6: Deliberate Failure Fallback (`3:40 – 4:10`)
- **Visual**: Switch briefly to terminal or show fallback demonstration.
- **Presenter (Voiceover)**:
  > *"In a live hackathon build, failure transparency matters. What happens if Rime’s remote API suffers a transient outage or 401 error?*
  > 
  > *Instead of silently hanging or dropping the WebRTC call, CookTalk’s `FallbackAdapter` catches the exception and immediately streams a local 24 kHz fallback audio notice in 1,256 milliseconds."*
- **Audio Clip**:
  > *"Sorry, I am having trouble connecting to the speech service right now. Please try again in a moment."*
- **Presenter (Voiceover)**:
  > *"The user gets explicit, audible feedback immediately, and the call remains active."*

---

### Beat 7: Summary & Verification (`4:10 – 4:30`)
- **Visual**: Display the headline comparison table from `README.md` and show the command line reproduction suite.
- **Presenter (Voiceover)**:
  > *"To summarize: CookTalk is ~8% faster end-to-end (5.8 seconds vs. our 6.3-second baseline) across realistic, tool-assisted cooking turns.
  > 
  > *Behind that is a 9.27x component speedup in TTS time-to-first-byte using Rime WebSocket `/ws3`, which eliminated speech synthesis as the bottleneck — while active connection warming and immediate spoken acknowledgments keep hands-free cooking responsive, grounded, and reliable.*
  > 
  > *Every single benchmark in this repository was measured live against real production endpoints and can be reproduced with a single command. Thank you!"*

---

## Pre-Recording Checklist

1. [ ] Ensure `.env` is loaded with valid `LIVEKIT_*`, `DEEPGRAM_API_KEY`, `GROQ_API_KEY`, and `RIME_API_KEY`.
2. [ ] Verify token server is running: `python web/token_server.py` on `http://127.0.0.1:8000`.
3. [ ] Verify Vite dev server is running: `npm run dev` on `http://127.0.0.1:5173`.
4. [ ] Verify agent worker is running: `python agent.py dev` with `WarmRimeTTS`.
5. [ ] Perform a quick dry-run test: connect from browser, ask "What ingredients for Cacio e Pepe?", verify clear audio and responsive Latency HUD.
6. [ ] Verify Groq daily token quota: ensure sufficient tokens remain on the free tier (or use fresh key) so live recording runs smoothly without 429 retries.
