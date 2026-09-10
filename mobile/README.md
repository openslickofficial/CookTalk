# CookTalk Mobile (Flutter Client)

A voice-first, hands-free cooking assistant mobile client built with Flutter and the official LiveKit Flutter SDK (`livekit_client: 2.11.0`). Connects directly to the existing CookTalk LiveKit backend (`agent/agent.py`) alongside the web frontend.

---

## 1. Core Design Principle: The Voice-First Boundary

CookTalk is designed for real kitchen environments where hands are coated in flour, olive oil, or raw ingredients. Touching a smartphone screen during active cooking creates friction and cross-contamination.

### The Disclosed Design Boundary
* **Pre-Session (Tap Permitted):** Before cooking begins and while hands are still clean, the user searches or selects a recipe from the catalog and taps **"Start Cooking"**.
* **In-Session (Strictly Voice-Driven & Passive):** Once the session is active, **every visual element on screen is a read-only reflection** of state reached via spoken interaction with the AI agent.
  * **No Tap-to-Navigate:** There are no "Next Step" or "Previous Step" buttons.
  * **Voice-Only Timer Cancellation (Phase M3.1):** Timer cards display label and active `MM:SS` countdown passively. The `[Cancel]` button has been removed. Timers can only be cancelled hands-free via voice commands (*"cancel the timer"*, *"stop the timer"*).
  * **No Manual Checklists:** Ingredients and sub-steps cannot be manually toggled.
  * **Voice Commands Drive 100% of State:** Say *"What's the next step?"*, *"Set a timer for 10 minutes for simmering"*, *"Cancel the simmer timer"*, or *"What can I substitute for buttermilk?"*. The screen passively updates in real-time via LiveKit data channel events.

---

## 2. Phase M3.1 Features & Architecture

### A. Search-As-You-Type (Local-Only, Typo-Tolerant)
* **Local Matching:** Autocompletes against local dishes (curated benchmark recipes + previously generated recipes) ranked first, and static dish names asset (`assets/data/static_dish_names.json`, ~120 dishes) ranked second.
* **Typo-Tolerant Levenshtein Distance:** Matches words and transliterations smoothly (e.g. `panner` matches `paneer`).
* **Zero Network Keystroke Guarantee:** No network requests and zero LLM calls happen while typing.

### B. Tap Behavior & Confirm-To-Generate Sheet
* **Existing Dish Tap:** Opens recipe and launches cooking directly without calling LLM or regenerating.
* **New / Unverified Dish Tap:** Opens a Confirm-to-Generate Bottom Sheet:
  > *"We don't have [dish] yet. Generate with AI? Unverified — double-check safety-critical steps yourself."*
  `[Cancel]` / `[Generate]`
* **Server-Side Generation (`POST /api/generate-dish`):**
  * Normalizes dish name and checks dedup against existing recipes and generated cache before invoking LLM.
  * Strict schema generation with automatic repair retry.
  * Returns `verified: false, source: "ai_generated"`.
  * Preserved in server cache with no-regeneration guarantee on repeat searches.

### C. Trust Badges & Safety Disclosure
* **Trust Badges:**
  * Curated benchmark recipes (`scrambled_eggs`, `cacio_e_pepe`, `ribeye_steak`): Solid Green **`Verified`** badge.
  * AI-generated recipes: Subtle Amber **`AI-suggested, unverified`** badge.
* **Cooked Before Tag:** Dynamically shows **`Cooked before`** on dishes the user has previously cooked based on the dedicated per-user `cook_history` table.
* **First-Run Spoken Safety Disclosure:** On the user's first voice session with an unverified recipe, the voice copilot speaks:
  > *"This recipe was AI-suggested and hasn't been verified by a chef. Double-check cooking temperatures and times."*

### D. Recently Viewed Tab (Replaced Explore Tab)
* **Tab 2:** Dedicated `RecentlyViewedScreen` showing recipes in descending order of `last_cooked_at`.
* **Single Source of Truth:** Backed strictly by `cook_history`, automatically refreshing via `cookHistoryNotifier`.
* **Home Carousel Sync:** The home screen carousel reads from the exact same `cook_history` source.

---

## 3. Visual Theming & Design System

CookTalk Mobile implements a cohesive 2-core color brand theme matching the master design reference:
* **Brand Forest Green:** `#143826` (Primary dark surface, headers, typography, buttons)
* **Mint Lime Accent:** `#D2E68B` (Active floating nav pill, badges, accents, interactive highlights)
* **Listening Voice State:** Emerald Green (`#10B981`)
* **Speaking Voice State:** Sky Blue (`#0EA5E9`)

---

## 4. Architecture & Data Channel Protocol

The mobile app connects to LiveKit Cloud via tokens issued by `web/token_server.py`. Once connected, bidirectional communication occurs over LiveKit audio tracks and reliable data channels.

### Inbound Events (Agent -> Mobile)
1. **`recipe_state`**:
   ```json
   {
     "type": "recipe_state",
     "recipe_id": "scrambled_eggs",
     "recipe_name": "Classic French Soft-Curd Scrambled Eggs",
     "current_step": 1,
     "total_steps": 5,
     "instruction": "Crack four eggs into a cold, unheated nonstick skillet..."
   }
   ```
2. **`timer_started`**:
   ```json
   {
     "type": "timer_started",
     "label": "simmer gravy",
     "duration_seconds": 600,
     "expires_at": 1741400000.0
   }
   ```
3. **`timer_completed`**:
   ```json
   {
     "type": "timer_completed",
     "label": "simmer gravy"
   }
   ```
4. **`timer_cancelled`**:
   ```json
   {
     "type": "timer_cancelled",
     "label": "simmer gravy"
   }
   ```
5. **`turn_metrics`**:
   ```json
   {
     "type": "turn_metrics",
     "agent_response": "I've cancelled the simmer timer.",
     "tts_ttfb_ms": 320,
     "latency_ms": 480
   }
   ```

### Outbound Events (Mobile -> Agent)
* **`select_recipe`**: Upon connecting to the room, the mobile app sends:
  ```json
  {
    "type": "select_recipe",
    "recipe_id": "<id>",
    "verified": false,
    "is_first_time": true
  }
  ```
  If `verified == false` and `is_first_time == true`, the agent speaks the unverified safety disclosure before proceeding.

---

## 5. Getting Started & Running

### Prerequisites
* Flutter SDK (3.47+)
* Android SDK (API 34) or iOS Toolchain
* CookTalk Token Server running (`agent\venv\Scripts\python.exe web/token_server.py`)
* CookTalk LiveKit Agent worker running (`agent\venv\Scripts\python.exe agent/agent.py start`)

### Running on Android Emulator
```bash
cd mobile
flutter run -d emulator-5554
```


---

## 6. Phase M6: Enhanced Conversational Edge Cases & Wave Visual

### A. Expanded Session-End Intents (TASK 1)

**Goodbye Phrase Recognition:**
The agent now recognizes a broad range of goodbye phrasings beyond exact matches:
- "that's it"
- "I'm done"
- "stop"
- "thanks, bye" / "thanks bye"
- "goodbye"
- "see you later"
- "I'm finished"
- "that'll do"

**Timer-on-Exit Behavior (DESIGN DECISION):**
When the user attempts to end the session while timers are still active, the agent implements a **WARN-AND-CONFIRM** pattern:

1. **Does NOT silently discard active timers**
2. **Agent responds:** "Wait! You still have [N] active timer(s) running ([timer names]). End session anyway? Say 'yes' to confirm or 'cancel' to keep cooking."
3. **User must explicitly confirm** to end with active timers

**Rationale:** Prevents accidental timer loss in noisy kitchens. Users can always cancel timers first if desired, but explicit confirmation guards against mishearing "goodbye" during active cooking.

**Implementation:** New `end_session()` tool checks `active_timers` dict and responds with confirmation prompt if non-empty.

---

### B. Multi-Timer Toolkit with Disambiguation (TASK 2)

**New Timer Tools:**
1. **`get_timer_remaining(label)`** - Read-only check of remaining time
   - If multiple timers and no label specified: lists all active timers
2. **`modify_timer(new_duration_seconds, label)`** - Change total duration
3. **`extend_timer(add_seconds, label)`** - Add time to existing timer

**Multi-Timer Disambiguation:**
- **CRITICAL RULE:** If 2+ timers are active and the command doesn't specify which timer (e.g., "add 5 minutes to the timer"), the agent **MUST ASK** which timer by name.
- **Never guesses** or defaults to most recent.
- Example response: *"You have 2 timers running (pasta, sauce). Which one do you want to extend?"*

**Implementation:**
- Each tool checks `len(copilot.active_timers) > 1` and `label is None`
- Returns disambiguation prompt listing timer names if ambiguous
- User must specify in follow-up query

---

### C. Step Navigation Refinement (TASK 3)

**New Navigation Tools:**
1. **`peek_next_step()`** - Preview what's next WITHOUT advancing current step
   - Use case: "What's coming up?" without moving forward yet
2. **`jump_to_step(step_number)`** - Arbitrary navigation to any step
   - Accepts explicit step number (not just sequential next/previous)
   - Validates against recipe length and provides boundary feedback

**Enhanced Navigation Capabilities:**
- `next_step()` - Advance forward (existing)
- `previous_step()` - Go back one (existing)
- `repeat_step()` - Repeat current verbatim (existing)
- `peek_next_step()` - **NEW:** Preview without advancing
- `jump_to_step(N)` - **NEW:** Jump directly to step N

---

### D. Mid-Session Serving Change Decline (TASK 4)

**DESIGN DECISION: Explicit Decline**

When asked to change servings mid-recipe, the agent declines cleanly rather than attempting to reconcile already-spoken quantities.

**Agent Response:**
> *"Let's finish this batch — I'll scale the next one."*

**Rationale:**
- User may have already measured/added ingredients based on original serving size
- Retroactively adjusting quantities mid-stream creates confusion and potential waste
- Clean decline sets expectation without disrupting flow

**Known Limitation:** Serving size changes are only supported **before starting** the recipe. This is documented and disclosed conversationally.

---

### E. Critical-Value Confirmation (TASK 5)

**Confirmation Round-Trip for Safety-Critical Values:**

For **timer durations** and **temperature values** specifically, the agent implements a confirmation pattern to guard against STT mishearing in noisy kitchens.

**Pattern:**
1. User: *"Set a timer for 50 minutes"*
2. Agent: *"Setting a 50-minute timer — that's right?"*
3. User confirms: *"Yes"*
4. Agent commits: *"Timer started for 50 minutes."*

**Temperature Example:**
1. User: *"Heat to 375 degrees"*
2. Agent: *"Got it, 375 degrees Fahrenheit — correct?"*
3. User confirms
4. Agent proceeds

**Scope:**
- **APPLIES TO:** Timer durations, oven temperatures, cooking temps
- **DOES NOT APPLY TO:** Ingredient queries, substitutions, step navigation, general questions
- Avoids adding friction to non-critical queries while protecting safety-sensitive values

---

### F. Timer Alert Queuing Extended (TASK 6)

**Phase M5 Baseline:** Timer alerts queue if another alert is already speaking (alert-vs-alert collision).

**Phase M6 Enhancement:** Timer alert queuing now covers **alert-vs-active-answer collision**.

**Scenario:**
- Agent is mid-sentence answering an unrelated question (e.g., explaining a substitution)
- Timer expires while agent is still speaking
- **Behavior:** Timer alert is queued and spoken immediately after the current utterance completes
- **No overlap or interruption** of active speech

**Implementation:** Uses existing `_timer_alert_lock` to serialize all timer announcements, whether colliding with another alert or an active conversational response.

---

### G. Connection-Issue Handling (TASK 7)

**Spoken Connection Notices:**

When a connection problem is detected, the agent speaks a plain notice through the **same utterance-subtitle bubble** used for every other spoken line:

> *"You're facing a connection issue — reconnecting now."*

**Design Principles:**
- **Never a raw error string** (no stack traces or technical codes)
- **Never a separate error UI element** (no red banners or modal dialogs)
- **Conversational tone** matching the agent's voice personality
- Appears in the same speech bubble UI as normal responses

**Rationale:** Maintains conversational flow and reduces visual clutter. The user hears and sees the notice as part of the natural dialogue, not as a jarring system error.

---

### H. Animated Amplitude-Reactive Waveform (TASK 8)

**Visual Replacement:** Static mic element replaced with **real audio-level driven waveform**.

**Behavior:**
- **While Listening:** Bar heights react to **mic input levels** (user speech amplitude)
- **While Speaking:** Bar heights react to **agent output levels** (TTS audio amplitude)
- **Smooth Easing:** Frame-to-frame transitions use animation curves (not jumpy/jittery)
- **Accessibility:** Respects OS **reduced-motion** settings
  - If reduced-motion enabled: Static bars, no animation
  - User experience remains functional without relying on motion

**Implementation:**
- Driven by **real audio buffers**, not decorative/random animation
- Uses platform audio level APIs (iOS: AVAudioRecorder metering, Android: AudioRecord amplitude)
- Implements `MediaQuery.of(context).disableAnimations` check for reduced-motion

**Visual Design:**
- 5-7 vertical bars
- Height maps to normalized amplitude (0.0 - 1.0 range)
- Color matches voice state (Listening: Emerald, Speaking: Sky Blue, Connecting: Mint Lime)

---

### I. Tool Inventory Summary (Phase M6)

**All Available Tools:**
1. `set_active_recipe` - Switch recipe
2. `get_current_step` - Current step info
3. `next_step` - Advance forward
4. `previous_step` - Go back
5. `repeat_step` - Repeat verbatim
6. `peek_next_step` - **NEW:** Preview next without advancing
7. `jump_to_step` - **NEW:** Jump to specific step number
8. `get_ingredient_quantity` - Query ingredient amount
9. `get_recipe_ingredients` - List recipe ingredients
10. `suggest_substitution` - Get substitute options (allergy-filtered)
11. `check_ingredient_safety` - Explicit allergen check
12. `start_cooking_timer` - Start new timer
13. `cancel_cooking_timer` - Stop timer
14. `get_timer_remaining` - **NEW:** Check remaining time
15. `modify_timer` - **NEW:** Change total duration
16. `extend_timer` - **NEW:** Add time to timer
17. `end_session` - **NEW:** End session with timer check

---

### J. Live Verification Test Plan (TASK 9)

**Test Scenarios:**

1. **Multi-Timer Disambiguation:**
   - Start 2 timers: "Set a 5-minute timer for pasta" + "Set a 10-minute timer for sauce"
   - Command: "Add 3 minutes to the timer" (ambiguous)
   - **Expected:** Agent asks which timer (pasta or sauce)
   - **Verify:** Agent does NOT auto-select or guess

2. **Critical-Value Confirmation:**
   - Command: "Set a timer for 45 minutes"
   - **Expected:** Agent confirms "45 minutes — that's right?" before starting
   - User says "Yes"
   - **Verify:** Timer starts only after confirmation

3. **Timer-on-Exit Behavior:**
   - Start a timer
   - Command: "I'm done" or "Goodbye"
   - **Expected:** Agent warns about active timer and asks for confirmation
   - **Verify:** Session does NOT end until user explicitly confirms

4. **Wave Amplitude Reactivity:**
   - Start session and speak clearly
   - **Expected (Listening State):** Wave bars visibly react to speech volume
   - Agent responds
   - **Expected (Speaking State):** Wave bars react to TTS output amplitude
   - **Verify:** Movement is driven by real audio, not decorative

5. **Peek vs. Advance Navigation:**
   - Command: "What's next?" (should use peek_next_step)
   - **Expected:** Agent previews next step WITHOUT advancing current step
   - **Verify:** Step counter does not increment
   - Command: "Next step" (should use next_step)
   - **Verify:** Now step counter advances

6. **Session End Confirmation Flow:**
   - Start timer
   - Say "Thanks, bye"
   - Agent warns about timer
   - Say "Yes, end it"
   - **Verify:** Session ends despite active timer

---

## 7. Timer Alert Delivery: Background Audio Only

### Audio-Only Timer Alerts (No Push Notifications)

**Design Decision:** Timer alerts are delivered exclusively via **background audio** using LiveKit WebRTC audio, not via local or push notifications.

**How It Works:**
1. Timer expires server-side in the agent (`agent/agent.py:723`)
2. Agent calls `copilot.session.say("Ding ding! Your timer for {label} is done.")`
3. Audio plays through the active LiveKit audio session
4. Mobile app uses `audio_session` package configured for background playback
5. iOS: `AVAudioSessionCategory.playback` + `UIBackgroundModes: audio`
6. Android: `AndroidAudioUsage.voiceCommunication` + `AndroidAudioContentType.speech`

**Background Playback Support:**
- ✅ **App backgrounded (screen on):** Timer alert plays through phone speaker
- ✅ **App backgrounded + screen locked:** Timer alert plays through phone speaker
- ✅ **Bluetooth/wired headphones connected:** Timer alert routes to headphones

**Critical Limitation:**
- ❌ **If the OS kills the app process** (low memory pressure, force quit, battery optimization), timer alerts will NOT play
- The timer still runs server-side, but audio playback requires the app process to remain alive (suspended but not terminated)
- This is a known trade-off of the background-audio-only approach

**Why No Push Notifications?**
- Avoids notification permission prompts and infrastructure complexity
- Aligns with voice-first, in-session design (timer alerts are conversational utterances, not system notifications)
- Background audio provides sufficient coverage for typical cooking session durations (10-30 minutes)

**User Guidance:**
- Keep the app open (backgrounded) during active cooking
- Avoid force-quitting the app while timers are running
- If extended idle time is expected, consider setting a phone timer as backup

---

## 8. Design Decision Record

**Timer-on-Exit:** WARN-AND-CONFIRM pattern chosen over silently keeping timers running post-session. Rationale: Explicit user control prevents accidental timer loss while maintaining kitchen safety.

**Mid-Session Serving Change:** DECLINE pattern chosen over attempting runtime quantity reconciliation. Rationale: Prevents ingredient waste and confusion when user has already measured based on original servings.

**Critical-Value Confirmation:** Applied ONLY to timers and temperatures. Rationale: Balances safety (guards against STT mishearing of numeric values) with conversational flow (no friction for non-critical queries).

**Multi-Timer Disambiguation:** ALWAYS ASK when ambiguous, never guess. Rationale: Incorrect timer modification in a kitchen environment has immediate negative consequences (burnt food, safety hazards).

