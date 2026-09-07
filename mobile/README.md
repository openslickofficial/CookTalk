# CookTalk Mobile (Flutter Client)

A voice-first, hands-free cooking assistant mobile client built with Flutter and the official LiveKit Flutter SDK (`livekit_client: 2.11.0`). Connects directly to the existing CookTalk LiveKit backend (`agent/agent.py`) alongside the web frontend.

---

## 1. Core Design Principle: The Voice-First Boundary

CookTalk is designed for real kitchen environments where hands are coated in flour, olive oil, or raw ingredients. Touching a smartphone screen during active cooking creates friction and cross-contamination.

### The Disclosed Design Boundary
* **Pre-Session (Tap Permitted):** Before cooking begins and while hands are still clean, the user selects a recipe from the catalog and taps **"Start Cooking"**.
* **In-Session (Strictly Voice-Driven & Passive):** Once the session is active, **every visual element on screen is a read-only reflection** of state reached via spoken interaction with the AI agent.
  * **No Tap-to-Navigate:** There are no "Next Step" or "Previous Step" buttons.
  * **No Tappable Checklists:** Ingredients and sub-steps cannot be manually toggled.
  * **No Manual Timers:** Timers cannot be manually created, paused, or dismissed on-screen.
  * **Voice Commands Drive 100% of State:** Say *"What's the next step?"*, *"Set a timer for 10 minutes for resting the batter"*, or *"What can I substitute for buttermilk?"*. The screen passively updates in real-time via LiveKit data channel events.

---

## 2. Visual Theming & Design System

CookTalk Mobile implements full light and dark `ThemeData` adhering to `ThemeMode.system` by default, with a manual toggle in the app bar that updates dynamically without resetting audio connections or room state.

### Color Palette
* **Primary Brand Accent:** Warm Amber / Orange (`#FF7A00`) — represents culinary warmth, action buttons, and active step progress.
* **Secondary Highlight:** Saffron / Gold (`#FFB300`) — accent badge and timer highlighting.
* **Status Success / Active:** Emerald Green (`#10B981`) — voice listening state and completed milestones.
* **Utility / Timer Accent:** Sky Blue (`#0EA5E9`) — active countdown timers.

### Surface Contrasts
* **Light Theme:**
  * Background: `#F8F9FA`
  * Card Surface: `#FFFFFF` (1px `#E2E8F0` border, subtle elevation)
  * Text: High-contrast Slate (`#1E293B`, `#64748B`)
* **Dark Theme:**
  * Background: `#0D0F12` (deep OLED black)
  * Card Surface: `#161920` / `#222733` (subtle border `#2A3241`)
  * Text: Crisp Off-White (`#F8FAFC`, `#94A3B8`)

---

## 3. Architecture & Data Channel Protocol

The mobile app connects to LiveKit Cloud via tokens issued by `web/token_server.py`. Once connected, bidirectional communication occurs over LiveKit audio tracks and reliable data channels.

### Inbound Events (Agent -> Mobile)
The agent emits JSON payloads over the data channel which `InSessionScreen` handles passively:

1. **`recipe_state`**:
   ```json
   {
     "type": "recipe_state",
     "recipe_id": "pancakes",
     "title": "Golden Diner-Style Fluffy Buttermilk Pancakes",
     "step_index": 2,
     "total_steps": 5,
     "instruction": "Pour wet ingredients into dry, whisk gently until just combined.",
     "ingredients": [...]
   }
   ```
   *Passively advances the recipe card, step count badge, and linear progress bar.*

2. **`timer_started`**:
   ```json
   {
     "type": "timer_started",
     "label": "Batter Rest",
     "duration_seconds": 600
   }
   ```
   *Instantiates a passive countdown timer card with a local 1-second ticker.*

3. **`timer_completed`**:
   ```json
   {
     "type": "timer_completed",
     "label": "Batter Rest"
   }
   ```
   *Automatically removes the timer card.*

4. **`turn_metrics`**:
   ```json
   {
     "type": "turn_metrics",
     "stt_latency_ms": 280,
     "llm_ttft_ms": 480,
     "tts_ttfb_ms": 401
   }
   ```
   *Updates the agent performance indicator strip.*

### Outbound Events (Mobile -> Agent)
* **`select_recipe`**: Upon connecting to the room, the mobile app sends `{ "type": "select_recipe", "recipe_id": "<id>" }` so the agent initializes the session with the user's pre-selected recipe context.

---

## 4. Getting Started & Running

### Prerequisites
* Flutter SDK (3.47+)
* Android SDK (API 34) or iOS Toolchain
* CookTalk Token Server running (`python -m uvicorn web.token_server:app --host 0.0.0.0 --port 8000`)
* CookTalk LiveKit Agent worker running (`python agent/agent.py dev`)

### Running on Android Emulator
The Android emulator maps host `localhost` to `10.0.2.2`. The app automatically detects this default:
```bash
cd mobile
flutter run
```

### Running on a Physical Device
Ensure your phone is connected to the same Wi-Fi network as your workstation, then specify your workstation's LAN IP address when running or in `lib/main.dart`:
```bash
flutter run --dart-define=API_URL=http://192.168.1.X:8000
```
