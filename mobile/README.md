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
