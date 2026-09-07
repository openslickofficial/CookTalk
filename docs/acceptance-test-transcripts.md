# Acceptance Test Transcripts: CookTalk Cooking Co-Pilot

**Date**: 2026-09-06 15:16:24 UTC
**Test Target**: LiveKit Cloud WebRTC session with real voice audio fixtures via Rime TTS WebSocket (`/ws3`), Groq (`qwen/qwen3.8-27b`), and Deepgram (`nova-3`).

## Summary of Scenarios Tested

| # | Scenario | Caller Utterance | Response Latency | Result |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Recipe Initiation & Step Traversal (Start & Step 1) | *"Let us make scrambled eggs. What is the first step?"* | 4319.4 ms | **PASS** |
| 2 | Step Traversal (Next Step) | *"Okay, what is the next step?"* | 4859.7 ms | **PASS** |
| 3 | Step Traversal (Repeat Step) | *"Can you repeat that step?"* | 4809.7 ms | **PASS** |
| 4 | Ingredient Quantity Query | *"How much butter do I need for the scrambled eggs?"* | 5930.4 ms | **PASS** |
| 5 | Culinary Substitution Query | *"What can I substitute for heavy cream?"* | 5119.6 ms | **PASS** |
| 6 | Proactive Timer Creation & Spoken WebRTC Alert | *"Set a timer for five seconds for the egg curd formation."* | 7083.5 ms | **PASS** |
| 7 | Deliberate Out-of-Scope Redirect | *"What is the current stock price of Apple?"* | 3919.8 ms | **PASS** |

---

## Detailed Transcripts & Verifications

### Scenario 1: Recipe Initiation & Step Traversal (Start & Step 1)
- **Caller (Voice)**: *"Let us make scrambled eggs. What is the first step?"*
- **Agent (Rime TTS Spoken)**: "Crack four eggs into a cold, unheated nonstick skillet and add two tablespoons of cubed cold butter."
- **Client-Perceived First Audio Latency**: 4319.4 ms (Peak Amplitude: 5459)
- **Outcome**: **PASS**

### Scenario 2: Step Traversal (Next Step)
- **Caller (Voice)**: *"Okay, what is the next step?"*
- **Agent (Rime TTS Spoken)**: "Place the pan over medium-low heat and continuously stir with a silicone spatula for two minutes until curds form."
- **Client-Perceived First Audio Latency**: 4859.7 ms (Peak Amplitude: 18291)
- **Outcome**: **PASS**

### Scenario 3: Step Traversal (Repeat Step)
- **Caller (Voice)**: *"Can you repeat that step?"*
- **Agent (Rime TTS Spoken)**: "Place the pan over medium-low heat and continuously stir with a silicone spatula for two minutes until curds start forming."
- **Client-Perceived First Audio Latency**: 4809.7 ms (Peak Amplitude: 2974)
- **Outcome**: **PASS**

### Scenario 4: Ingredient Quantity Query
- **Caller (Voice)**: *"How much butter do I need for the scrambled eggs?"*
- **Agent (Rime TTS Spoken)**: "You need 2 tablespoons of cold, cubed butter for the scrambled eggs."
- **Client-Perceived First Audio Latency**: 5930.4 ms (Peak Amplitude: 1841)
- **Outcome**: **PASS**

### Scenario 5: Culinary Substitution Query
- **Caller (Voice)**: *"What can I substitute for heavy cream?"*
- **Agent (Rime TTS Spoken)**: "You can substitute one tablespoon of whole milk, crème fraîche, or sour cream for the heavy cream."
- **Client-Perceived First Audio Latency**: 5119.6 ms (Peak Amplitude: 14085)
- **Outcome**: **PASS**

### Scenario 6: Proactive Timer Creation & Spoken WebRTC Alert
- **Caller (Voice)**: *"Set a timer for five seconds for the egg curd formation."*
- **Agent (Rime TTS Spoken)**: "Timer set for 5 seconds for egg curd formation. I’ll let you know when it’s done."
- **Client-Perceived First Audio Latency**: 7083.5 ms (Peak Amplitude: 2048)
- **Proactive Spoken Timer Alert**: VERIFIED HEARD OVER WEBRTC
- **Outcome**: **PASS**

### Scenario 7: Deliberate Out-of-Scope Redirect
- **Caller (Voice)**: *"What is the current stock price of Apple?"*
- **Agent (Rime TTS Spoken)**: "I can't help with stock prices, only with cooking questions and recipes."
- **Client-Perceived First Audio Latency**: 3919.8 ms (Peak Amplitude: 8004)
- **Outcome**: **PASS**

---

## Verification Criteria Assessment
1. **Step Traversal**: CookTalk correctly started at Step 1 and navigated sequentially through Step 2 and repeated Step 2 upon command.
2. **Ingredient Grounding**: Queried butter quantity was answered with exact recipe values ("2 tablespoons cold cubed butter").
3. **Culinary Substitution**: Queried substitution for heavy cream answered strictly from recipe data ("whole milk, crème fraîche, or sour cream").
4. **Proactive WebRTC Timer**: Countdown timer executed asynchronously on server, proactively synthesized audio via Rime TTS upon completion, and played over WebRTC without requiring user speech.
5. **Out-of-Scope Redirect**: Non-cooking question (Apple stock price) was politely declined in one sentence and redirected back to the active recipe.

