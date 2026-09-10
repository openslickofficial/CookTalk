# CookTalk - Complete Application Summary

## 📋 Table of Contents
1. [Project Overview](#project-overview)
2. [System Architecture](#system-architecture)
3. [Technology Stack](#technology-stack)
4. [Database Schema](#database-schema)
5. [Live Cooking Session Logic](#live-cooking-session-logic)
6. [Voice Pipeline & Latency Optimization](#voice-pipeline--latency-optimization)
7. [Mobile App Architecture](#mobile-app-architecture)
8. [Web Frontend Architecture](#web-frontend-architecture)
9. [Deployment & Infrastructure](#deployment--infrastructure)
10. [Key Features](#key-features)
11. [Security & Privacy](#security--privacy)

---

## 1. Project Overview

**CookTalk** is a real-time, hands-free voice cooking assistant designed for busy, messy kitchens where hands are coated in flour, oil, or raw ingredients. Built for the **DataForge × Rime Hackathon**, it delivers ultra-low-latency voice interactions through an optimized WebRTC pipeline.

### Core Problem Solved
- **Traditional cooking apps require screen touches** → Cross-contamination, greasy fingerprints
- **Voice assistants have awkward pauses** → Frustrating kitchen experience
- **Recipe apps aren't conversational** → Can't ask questions mid-cooking

### Solution
- **100% hands-free voice control** during active cooking
- **Ultra-low latency pipeline** (~4.7s client-perceived response time)
- **Conversational AI co-pilot** with recipe knowledge, timers, substitutions
- **Cross-platform** (Web + Android mobile app)

---

## 2. System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      User Devices                                │
│                                                                  │
│    ┌──────────────────┐          ┌──────────────────┐          │
│    │  Android App     │          │   Web Browser    │          │
│    │  (Flutter)       │          │   (React/Vite)   │          │
│    └────────┬─────────┘          └────────┬─────────┘          │
└─────────────┼────────────────────────────┼────────────────────┘
              │                            │
              │ WebRTC (Opus Audio)        │ WebRTC + HTTPS
              │                            │
┌─────────────┼────────────────────────────┼────────────────────┐
│             │     LiveKit Cloud SFU       │                    │
│             └────────────┬────────────────┘                    │
│                          │                                     │
│         ┌────────────────┼────────────────┐                   │
│         │  CookTalk Agent Worker          │                   │
│         │  (LiveKit Agents Framework)     │                   │
│         └─────────────────────────────────┘                   │
│                          │                                     │
│           ┌──────────────┼──────────────┐                     │
│           │              │              │                     │
│      ┌────▼───┐     ┌───▼───┐     ┌───▼───┐                 │
│      │Deepgram│     │ Groq  │     │ Rime  │                 │
│      │ (STT)  │     │ (LLM) │     │ (TTS) │                 │
│      └────────┘     └───────┘     └───────┘                 │
└─────────────────────────────────────────────────────────────┘
              │
              │ Database Queries
              │
┌─────────────▼─────────────────────────────────────────────────┐
│                    Supabase Cloud                              │
│  ┌──────────┐  ┌─────────┐  ┌──────────────┐                │
│  │ profiles │  │ dishes  │  │ cook_history │                │
│  └──────────┘  └─────────┘  └──────────────┘                │
└────────────────────────────────────────────────────────────────┘
```

### Component Interaction Flow

```
User Speech → Microphone
    ↓
WebRTC Audio Stream (Opus) → LiveKit Cloud SFU
    ↓
Agent Worker receives PCM audio
    ↓
1. Silero VAD: Voice Activity Detection (endpointing)
    ↓
2. Deepgram STT: Speech-to-Text (streaming)
    ↓
3. Groq LLM: Natural Language Understanding + Tool Calling
    ↓
4. CookingCoPilot: Execute tool functions (recipe navigation, timers, etc.)
    ↓
5. Rime TTS: Text-to-Speech (WebSocket streaming)
    ↓
Audio chunks → LiveKit track
    ↓
WebRTC Audio Stream → User device
    ↓
Speaker output
```

---

## 3. Technology Stack

### Backend (Agent Worker)
| Component | Technology | Version | Purpose |
|-----------|------------|---------|---------|
| **Runtime** | Python | 3.11+ | Agent execution |
| **Framework** | LiveKit Agents | 1.8.0 | Real-time WebRTC orchestration |
| **VAD** | Silero VAD | 1.8.0 plugin | Voice activity detection |
| **STT** | Deepgram nova-3 | 1.8.0 plugin | Speech-to-text streaming |
| **LLM** | Groq qwen3.8-27b | OpenAI plugin | Fast token generation |
| **TTS** | Rime coda/astra | 1.8.0 plugin | WebSocket TTS streaming |
| **Data Channel** | LiveKit DataChannel | Built-in | Recipe state broadcasting |

### Frontend (Web)
| Component | Technology | Version | Purpose |
|-----------|------------|---------|---------|
| **Framework** | React | 18+ | UI components |
| **Build Tool** | Vite | Latest | Dev server + bundling |
| **WebRTC Client** | LiveKit JS SDK | Latest | Room connection |
| **Styling** | TailwindCSS-like | Custom | UI styling |
| **Icons** | Lucide React | Latest | Icon library |

### Mobile (Flutter)
| Component | Technology | Version | Purpose |
|-----------|------------|---------|---------|
| **Framework** | Flutter | 3.47+ | Cross-platform mobile |
| **WebRTC Client** | livekit_client | 2.11.0 | LiveKit connectivity |
| **Database** | Supabase Flutter | Latest | Database client |
| **State Management** | StatefulWidget | Built-in | Local state |
| **Storage** | SharedPreferences | Latest | Local persistence |

### Database & Auth
| Component | Technology | Purpose |
|-----------|------------|---------|
| **Database** | Supabase (PostgreSQL) | User profiles, dishes, history |
| **Authentication** | Supabase Auth | OAuth (Google), Email |
| **Storage** | Supabase Storage | (Future: Recipe images) |

### Infrastructure
| Component | Platform | Cost | Purpose |
|-----------|----------|------|---------|
| **Agent Worker** | LiveKit Cloud | FREE (1000 min/mo) | Agent execution |
| **Web Frontend** | Cloudflare Pages | FREE (unlimited) | Static hosting |
| **Token Server** | Cloudflare Functions | FREE (100k req/day) | JWT generation |
| **Database** | Supabase Cloud | FREE (500MB) | Data storage |
| **Mobile Distribution** | APK Direct Download | FREE | Android distribution |

---

## 4. Database Schema

### 4.1 Profiles Table (`profiles` or `user`)

Stores user account information and preferences.

```sql
CREATE TABLE profiles (
  id UUID PRIMARY KEY,                    -- User identifier
  email TEXT UNIQUE NOT NULL,             -- Email address
  full_name TEXT NOT NULL,                -- Display name
  avatar_url TEXT,                        -- Profile picture URL
  favorite_cuisines TEXT[],               -- Preferred cuisine types
  cooking_frequency TEXT,                 -- Cooking habit
  onboarding_completed BOOLEAN DEFAULT FALSE,
  allergies TEXT[],                       -- Food allergies
  favorites TEXT[] DEFAULT '{}',          -- 🆕 Favorite dish IDs
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_profiles_favorites ON profiles USING GIN (favorites);
```

**Key Fields:**
- `favorites` - Array of dish IDs the user has favorited
- `allergies` - Safety-critical: filters substitution suggestions
- `favorite_cuisines` - Used for recommendations

### 4.2 Dishes Table (`dishes`)

Stores both curated and AI-generated recipes.

```sql
CREATE TABLE dishes (
  id UUID PRIMARY KEY,                    -- Dish identifier
  slug TEXT UNIQUE NOT NULL,              -- URL-friendly ID
  title TEXT NOT NULL,                    -- Dish name
  description TEXT,                       -- Short description
  category TEXT,                          -- breakfast/lunch/dinner/snack/dessert
  cuisine TEXT,                           -- Italian, French, Asian, etc.
  prep_time_minutes INTEGER,              -- Prep time
  cook_time_minutes INTEGER,              -- Cook time
  servings INTEGER DEFAULT 2,             -- Serving count
  base_servings INTEGER DEFAULT 2,        -- Original recipe servings
  difficulty TEXT,                        -- Easy/Medium/Hard
  image_url TEXT,                         -- Dish photo
  is_trending BOOLEAN DEFAULT FALSE,      -- Featured on homepage
  verified BOOLEAN DEFAULT FALSE,         -- Hand-curated quality flag
  source TEXT DEFAULT 'curated',          -- 'curated' or 'ai_generated'
  normalized_name TEXT,                   -- Search index
  ingredients JSONB NOT NULL,             -- Array of ingredient objects
  steps JSONB NOT NULL,                   -- Array of step objects
  substitutions JSONB,                    -- Ingredient substitution map
  
  -- 🆕 User association
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT NOW(),
  
  CONSTRAINT fk_user FOREIGN KEY (user_id) 
    REFERENCES profiles(id) ON DELETE CASCADE
);

CREATE INDEX idx_dishes_user_id ON dishes(user_id);
CREATE INDEX idx_dishes_category ON dishes(category);
CREATE INDEX idx_dishes_verified ON dishes(verified);
```

**Key Fields:**
- `user_id` - Links dish to creator (for AI-generated dishes)
- `verified` - TRUE only for hand-authored benchmark recipes
- `ingredients` - JSONB array: `[{name, quantity, unit}, ...]`
- `steps` - JSONB array: `[{step_number, instruction}, ...]`
- `substitutions` - JSONB map: `{"butter": "ghee or olive oil", ...}`

**Ingredient Object Schema:**
```json
{
  "name": "butter",
  "quantity": "2",
  "unit": "tablespoons, cold and cubed"
}
```

**Step Object Schema:**
```json
{
  "step_number": 1,
  "instruction": "Crack four eggs into a cold, unheated nonstick skillet..."
}
```

### 4.3 Cook History Table (`cook_history`)

Tracks which dishes a user has viewed/cooked for "Recently Viewed" feature.

```sql
CREATE TABLE cook_history (
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  dish_id UUID REFERENCES dishes(id) ON DELETE CASCADE,
  last_cooked_at TIMESTAMP DEFAULT NOW(),
  
  PRIMARY KEY (user_id, dish_id)
);

CREATE INDEX idx_cook_history_user_timestamp 
  ON cook_history(user_id, last_cooked_at DESC);
```

**Usage:**
- Records every recipe view/session start
- UPSERT on `(user_id, dish_id)` updates timestamp
- Powers "Recently Viewed" section (sorted by `last_cooked_at`)
- Enables "Cooked Before" badge on recipe cards

---

## 5. Live Cooking Session Logic

### 5.1 Session Lifecycle

```
1. User Selection (Pre-Session)
   ├─ Search/Browse recipes
   ├─ Tap "Start Cooking"
   └─ App sends select_recipe event

2. Session Initialization
   ├─ Mobile/Web connects to LiveKit room
   ├─ Token generated by token server
   ├─ Agent worker joins room
   ├─ Bidirectional audio + data channels established
   └─ Recipe loaded into CookingCoPilot state

3. Active Cooking (Voice-Only)
   ├─ User speaks → Silero VAD detects speech
   ├─ Deepgram transcribes → text
   ├─ Groq LLM processes → tool calls
   ├─ CookingCoPilot executes tools
   ├─ Rime TTS synthesizes response
   └─ Audio plays on user device
   
4. Data Channel Updates
   ├─ recipe_state events (step changes)
   ├─ timer_started/completed/cancelled
   ├─ turn_metrics (latency monitoring)
   └─ UI updates passively (no manual interaction)

5. Session End
   ├─ User says goodbye phrases
   ├─ Agent checks for active timers
   ├─ Warns if timers running
   ├─ User confirms → session ends
   └─ History recorded to cook_history table
```

### 5.2 Tool Functions (17 Total)

The agent exposes 17 asynchronous LiveKit function tools:

#### **Recipe Navigation (7 tools)**
1. `set_active_recipe(recipe_name)` - Switch recipe
2. `get_current_step()` - Current step info
3. `next_step()` - Advance forward
4. `previous_step()` - Go back
5. `repeat_step()` - Repeat current step verbatim
6. `peek_next_step()` - Preview next WITHOUT advancing
7. `jump_to_step(step_number)` - Jump to specific step

#### **Ingredient Queries (4 tools)**
8. `get_ingredient_quantity(name)` - Query amount
9. `get_recipe_ingredients()` - List all ingredients
10. `suggest_substitution(ingredient)` - Get alternatives (allergy-filtered)
11. `check_ingredient_safety(ingredient)` - Explicit allergen check

#### **Timer Management (5 tools)**
12. `start_cooking_timer(duration_seconds, label)` - Start timer
13. `cancel_cooking_timer(label)` - Stop timer
14. `get_timer_remaining(label)` - Check remaining time
15. `modify_timer(new_duration, label)` - Change total duration
16. `extend_timer(add_seconds, label)` - Add time

#### **Session Control (1 tool)**
17. `end_session()` - End session with timer check

### 5.3 Data Channel Protocol

**Outbound Events (Mobile/Web → Agent)**

```json
{
  "type": "select_recipe",
  "recipe_id": "scrambled_eggs",
  "verified": true,
  "is_first_time": false
}
```

**Inbound Events (Agent → Mobile/Web)**

**Recipe State Update:**
```json
{
  "type": "recipe_state",
  "recipe_id": "scrambled_eggs",
  "recipe_name": "Classic French Soft-Curd Scrambled Eggs",
  "current_step": 2,
  "total_steps": 5,
  "instruction": "Place the pan over medium-low heat..."
}
```

**Timer Events:**
```json
// Timer started
{
  "type": "timer_started",
  "label": "simmer sauce",
  "duration_seconds": 600,
  "expires_at": 1741400000.0
}

// Timer completed (proactive alert)
{
  "type": "timer_completed",
  "label": "simmer sauce"
}

// Timer cancelled
{
  "type": "timer_cancelled",
  "label": "simmer sauce"
}
```

**Turn Metrics (Latency Monitoring):**
```json
{
  "type": "turn_metrics",
  "agent_response": "Let's move to step 3.",
  "tts_ttfb_ms": 386,
  "latency_ms": 4740
}
```

### 5.4 Voice Command Examples

**Navigation:**
- "What's the next step?" → calls `peek_next_step()`
- "Next step" → calls `next_step()`
- "Go back" → calls `previous_step()`
- "Repeat that" → calls `repeat_step()`
- "Jump to step 4" → calls `jump_to_step(4)`

**Ingredients:**
- "How much butter?" → calls `get_ingredient_quantity("butter")`
- "What can I substitute for buttermilk?" → calls `suggest_substitution("buttermilk")`
- "Can I use peanut oil?" → calls `check_ingredient_safety("peanut oil")`

**Timers:**
- "Set a timer for 10 minutes" → calls `start_cooking_timer(600, "timer")`
- "Set a 5-minute timer for pasta" → `start_cooking_timer(300, "pasta")`
- "Cancel the pasta timer" → `cancel_cooking_timer("pasta")`
- "How much time left on the sauce timer?" → `get_timer_remaining("sauce")`
- "Add 3 minutes to the pasta timer" → `extend_timer(180, "pasta")`

**Session:**
- "I'm done" / "Goodbye" → calls `end_session()`

### 5.5 Multi-Timer Disambiguation

**Critical Rule:** If 2+ timers active and command doesn't specify which:

**User:** "Add 5 minutes to the timer"  
**Agent:** "You have 2 timers running (pasta, sauce). Which one do you want to extend?"  
**User:** "The pasta timer"  
**Agent:** "Added 5 minutes to your pasta timer."

### 5.6 Allergy Safeguard System

**Profile-Based Filtering:**
1. User allergies loaded at session start
2. `suggest_substitution()` automatically filters out allergens
3. `check_ingredient_safety()` explicitly warns if dangerous

**Example:**
```python
User Profile: allergies = ["peanut", "tree nuts"]

User: "Can I use peanut oil?"
Agent calls: check_ingredient_safety("peanut oil")
Response: "⚠️ CAUTION: Your profile lists a severe peanut allergy. 
           Do NOT use peanut oil."
```

**Substitution Filtering:**
```python
User: "What can I substitute for butter?"
Candidates: ["ghee", "olive oil", "peanut oil", "coconut oil"]
Filtered (if peanut allergy): ["ghee", "olive oil", "coconut oil"]
Agent: "For butter: try ghee or olive oil or coconut oil"
```

---

## 6. Voice Pipeline & Latency Optimization

### 6.1 Pipeline Components

```
User Speech (16 kHz audio)
    ↓
Silero VAD (Neural turn detection)
    ├─ Continuous background silence frames
    ├─ 800ms trailing silence in fixtures
    └─ min_endpointing_delay: 0.6s
    ↓
Deepgram STT (nova-3 streaming)
    ├─ WebSocket streaming
    ├─ Interim results
    └─ Final transcript
    ↓
Groq LLM (qwen3.8-27b)
    ├─ Streaming tokens
    ├─ Function calling
    ├─ Dynamic backoff on rate limits
    └─ Context sanitization
    ↓
CookingCoPilot Tool Execution
    ├─ Immediate acknowledgment spoken
    ├─ Tool function executed
    └─ Result returned to LLM
    ↓
Rime TTS (coda/astra WebSocket)
    ├─ WarmRimeTTS with keepalive
    ├─ WebSocket /ws3 endpoint
    ├─ PCM 24kHz streaming chunks
    └─ First audio in ~386ms
    ↓
LiveKit Audio Track
    ↓
User Device Speaker
```

### 6.2 Performance Metrics

**Latency Breakdown (Median):**
- Rime TTS TTFB: **386.0 ms** (9.27x faster than HTTP baseline)
- Tool Acknowledgment: **875.0 ms** (spoken "One sec")
- Client First Sound: **4,740.7 ms** (wall-clock from speech end)
- Substantive Answer: **4,924.4 ms** (full grounded reply)
- Total Turn Duration: **5,859.3 ms** (including audio playout)

**Component Speedup:**
- Phase 1 (HTTP baseline): 3,578 ms TTFB
- Phase 6 (WebSocket /ws3): **386 ms TTFB**
- **Speedup: 9.27x faster**

**Reliability:**
- Call completion rate: **100%** (30/30 trials)
- Question answered rate: **90%** (27/30, 3 hit rate limits)
- Zero hangs or crashes

### 6.3 Latency Optimizations Applied

**1. WebSocket Streaming (Rime /ws3)**
- Eliminates HTTP overhead
- Chunked audio streaming
- First audio in ~386ms vs 3,578ms

**2. WarmRimeTTS Connection Pooling**
- max_session_duration: 12s (avoids 18s server timeout)
- Background keepalive every 10s
- Pre-warms connections during idle
- Eliminates cold handshake penalty

**3. Tool Acknowledgment Masking**
- Speaks "One sec" immediately on tool dispatch
- Masks LLM dual-pass reasoning delay
- User hears response in <1s

**4. Dynamic Groq Backoff**
- Parses upstream rate limit reset time
- Waits exactly as long as needed (not fixed delay)
- Max backoff: 3s (maintains conversation flow)

**5. VAD Tuning**
- 800ms trailing silence in fixtures
- Continuous background silence frames
- min_endpointing_delay: 0.6s (prevents mid-sentence cutoffs)

**6. Context Sanitization**
- Collapses consecutive user turns
- Prevents empty LLM completions
- Reduces token waste

---

## 7. Mobile App Architecture

### 7.1 Flutter Project Structure

```
mobile/
├── lib/
│   ├── main.dart                    # App entry + AuthGate
│   ├── config/
│   │   └── supabase_config.dart     # Supabase credentials
│   ├── models/
│   │   ├── user_profile.dart        # UserProfile model
│   │   └── dish.dart                # Dish, Ingredient, RecipeStep models
│   ├── services/
│   │   └── supabase_service.dart    # Database + auth logic
│   ├── screens/
│   │   ├── onboarding_screen.dart   # First-run questionnaire
│   │   ├── auth_screen.dart         # Google OAuth login
│   │   ├── home_screen.dart         # Recipe browsing
│   │   ├── recently_viewed_screen.dart  # History tab
│   │   ├── search_screen.dart       # Search (future)
│   │   ├── profile_screen.dart      # Settings + preferences
│   │   ├── recipe_detail_screen.dart    # Recipe preview
│   │   └── cooking_session_screen.dart  # Live WebRTC session
│   └── widgets/
│       ├── user_avatar.dart         # DiceBear avatar support
│       ├── recipe_card.dart         # Recipe UI component
│       └── ...
├── android/
│   ├── app/
│   │   ├── build.gradle.kts         # Release signing config
│   │   └── src/main/
│   │       ├── AndroidManifest.xml  # Permissions
│   │       └── res/                 # Icons, splash screens
│   └── key.properties              # Signing key path
├── assets/
│   ├── images/
│   │   ├── app_icon.png            # App icon
│   │   ├── splash.png              # Light splash
│   │   └── splash_dark.png         # Dark splash
│   └── data/
│       └── static_dish_names.json  # Local search index
└── pubspec.yaml                    # Dependencies
```

### 7.2 Key Dependencies

```yaml
dependencies:
  flutter: sdk: flutter
  livekit_client: ^2.11.0       # WebRTC connectivity
  supabase_flutter: ^latest     # Database client
  shared_preferences: ^latest   # Local storage
  http: ^latest                 # HTTP client
  flutter_svg: ^latest          # SVG avatar support
```

### 7.3 Mobile-Specific Features

**Voice-First Boundary:**
- Pre-session: Tap allowed (search, select recipe)
- In-session: **100% voice-only** (no buttons, no manual input)
- Post-session: Tap allowed (review, favorites)

**Recently Viewed Section:**
- Replaces "Explore" tab
- Shows last 6 viewed dishes
- Horizontal scrollable cards
- Powered by `cook_history` table

**Favorites Persistence:**
- Stored in `profiles.favorites` array
- Synced to Supabase on toggle
- Cached in SharedPreferences for offline
- Heart icon on recipe cards

**Search-As-You-Type:**
- Local fuzzy matching (Levenshtein distance)
- Typo-tolerant (e.g., "panner" → "paneer")
- Zero network calls while typing
- Searches local dishes + static names asset

**AI Generation Confirm Sheet:**
- Tapping non-existent dish opens bottom sheet
- "Generate with AI?" prompt
- Safety disclosure: "Unverified — double-check steps"
- Server endpoint: `/api/generate-dish`

**Waveform Visualization:**
- Real audio amplitude-driven bars
- Listening state: Reacts to mic input
- Speaking state: Reacts to agent output
- Respects OS reduced-motion settings

---

## 8. Web Frontend Architecture

### 8.1 Web Project Structure

```
web/
├── index.html                      # Entry point
├── style.css                       # Global styles
├── main.js                         # LiveKit client logic
├── token_server.py                 # JWT generation (dev)
├── functions/
│   └── token.ts                    # Cloudflare edge function
└── assets/
    └── icons/                      # UI icons
```

### 8.2 Web Features

**Real-Time Latency HUD:**
- Live metrics overlay
- Component breakdown: VAD, STT, LLM, TTS, E2E
- Updates every turn

**Amplitude-Reactive Waveform:**
- 5-7 vertical bars
- Height maps to audio amplitude
- Listening: Emerald green
- Speaking: Sky blue

**Recipe Card Navigator:**
- Current step display
- Step counter (e.g., "2 / 5")
- Passive updates via data channel

**Active Timer Widget:**
- Shows label + MM:SS countdown
- Multiple timers supported
- Proactive completion alerts

**Voice State Indicator:**
- Idle: Gray
- Connecting: Mint lime
- Listening: Emerald
- Speaking: Sky blue

---

## 9. Deployment & Infrastructure

### 9.1 Component Deployment

| Component | Platform | URL/Access | Cost |
|-----------|----------|------------|------|
| **Agent Worker** | LiveKit Cloud | Auto-deployed | FREE (1000 min/mo) |
| **Web Frontend** | Cloudflare Pages | `cooltalk.pages.dev` | FREE (unlimited) |
| **Token Server** | Cloudflare Functions | `/token` endpoint | FREE (100k req/day) |
| **Database** | Supabase Cloud | API URL | FREE (500MB) |
| **Mobile APK** | Direct Download | Google Drive, etc. | FREE |

### 9.2 API Keys Required

All free tiers:

1. **LiveKit Cloud** - WebRTC rooms
   - Sign up: https://cloud.livekit.io
   - Get: API Key + Secret + URL

2. **Deepgram** - Speech-to-text
   - Sign up: https://console.deepgram.com
   - Get: API Key ($200 free credit)

3. **Groq** - LLM inference
   - Sign up: https://console.groq.com
   - Get: API Key (14.4M tokens/day)

4. **Rime** - Text-to-speech
   - Sign up: https://app.rime.ai
   - Get: API Key (free tier)

5. **Supabase** - Database + auth
   - Sign up: https://supabase.com
   - Get: URL + Anon Key

### 9.3 Environment Variables

**Agent Worker:**
```bash
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=your_key
LIVEKIT_API_SECRET=your_secret
DEEPGRAM_API_KEY=your_key
GROQ_API_KEY=your_key
RIME_API_KEY=your_key
```

**Token Server (Cloudflare Functions):**
```bash
LIVEKIT_API_KEY=your_key
LIVEKIT_API_SECRET=your_secret
```

**Mobile App:**
```dart
// lib/config/supabase_config.dart
static const String supabaseUrl = 'your_url';
static const String supabaseAnonKey = 'your_key';

// lib/screens/main_nav_screen.dart
const tokenServerUrl = 'https://cooltalk.pages.dev/token';
const livekitUrl = 'wss://your-project.livekit.cloud';
```

---

## 10. Key Features

### 10.1 Phase M6 Enhancements

**1. Expanded Session-End Intents**
- Recognizes 8+ goodbye phrases
- Timer-on-exit warn-and-confirm pattern
- Prevents accidental timer loss

**2. Multi-Timer Toolkit**
- 3 new tools: `get_timer_remaining`, `modify_timer`, `extend_timer`
- Mandatory disambiguation when 2+ timers active
- Never guesses which timer user means

**3. Step Navigation Refinement**
- `peek_next_step()` - Preview without advancing
- `jump_to_step(N)` - Arbitrary navigation
- Enhanced capabilities beyond sequential next/prev

**4. Mid-Session Serving Change Decline**
- Clean decline: "Let's finish this batch"
- Prevents ingredient waste/confusion
- Serving changes only before session start

**5. Critical-Value Confirmation**
- Timer durations and temperatures require confirmation
- Guards against STT mishearing in noisy kitchens
- Example: "50 minutes — that's right?" → User confirms

**6. Timer Alert Queuing Extended**
- Phase M5: Alert-vs-alert queuing
- Phase M6: Alert-vs-answer queuing
- No overlapping speech from timers

**7. Connection-Issue Handling**
- Spoken notices via normal utterance bubble
- Conversational tone (not technical errors)
- Example: "You're facing a connection issue — reconnecting now."

**8. Amplitude-Reactive Waveform**
- Real audio-level driven animation
- Listening: Mic input amplitude
- Speaking: Agent output amplitude
- Accessibility: Respects reduced-motion settings

### 10.2 Allergy Safeguard Features

**Profile-Based Safety:**
- User allergies loaded at session start
- Automatic filtering in `suggest_substitution()`
- Explicit safety check via `check_ingredient_safety()`

**Real-Time Warnings:**
- If user proposes dangerous ingredient: Immediate warning
- If all substitutions contain allergens: Alternative suggestions
- Logged with ⚠️ emoji for visibility

### 10.3 Recently Viewed System

**Tracking:**
- Records every recipe view/session start
- Stored in `cook_history` table with timestamp
- UPSERT on `(user_id, dish_id)`

**Display:**
- Home screen: Shows last 6 dishes (horizontal carousel)
- Recently Viewed tab: Full history (descending order)
- "Cooked Before" badge on recipe cards

**Data Flow:**
```
User views recipe
    ↓
recordDishViewedInAI(dishId)
    ↓
recordCookHistory(dishId) called
    ↓
Upserts to cook_history table
    ↓
cookHistoryNotifier.value++ triggered
    ↓
UI auto-refreshes via listener
```

### 10.4 Favorites System

**Storage:**
- Array field in `profiles.favorites`
- Synced to Supabase on every toggle
- Cached in SharedPreferences for offline

**UI:**
- Heart icon on recipe cards
- Toggle in-place (no screen navigation)
- Fetchable via `fetchFavoriteDishes()`

**Sync Logic:**
```dart
toggleFavorite(dishId)
    ↓
Update in-memory Set
    ↓
_syncFavoritesToProfile()
    ↓
Update Supabase: profiles.favorites = [array]
    ↓
Save to local SharedPreferences
```

---

## 11. Security & Privacy

### 11.1 Authentication

**Providers:**
- Google OAuth via Supabase Auth
- Apple Sign-In (disabled, not configured yet)
- Email/password (future)

**Token Flow:**
```
1. User signs in via OAuth
2. Supabase returns session token
3. Profile fetched/created in profiles table
4. Stored in SharedPreferences
5. LiveKit tokens generated per-session
```

**LiveKit Tokens:**
- Short-lived JWT (valid for session duration)
- Generated by token server with API secret
- Contains room name + participant name
- Issued on-demand per cooking session

### 11.2 Data Privacy

**User Data Stored:**
- Profile: Name, email, avatar, preferences
- Dishes: User-generated recipes (private to user)
- History: Which recipes user viewed (private)
- Favorites: Which recipes user favorited (private)

**Data Isolation:**
- `fetchDishes()` filters by `user_id`
- No cross-user data leakage
- Each user sees only their own AI-generated dishes

**API Keys:**
- Never exposed to client
- Agent worker uses server-side env vars
- Token server uses Cloudflare secrets
- No keys in mobile APK

### 11.3 Allergen Safety

**Critical Safety Feature:**
- User allergies stored in profile
- Automatic filtering in real-time
- Explicit warnings when dangerous ingredient proposed
- High-priority logging with ⚠️ emoji

**Example Flow:**
```
User has peanut allergy in profile
    ↓
User: "Can I use peanut oil?"
    ↓
check_ingredient_safety("peanut oil") called
    ↓
Detects "peanut" in allergies list
    ↓
Returns: "⚠️ CAUTION: Your profile lists a severe peanut allergy. 
          Do NOT use peanut oil."
```

---

## 12. Future Enhancements

### Planned Features
- [ ] Multi-language support (Spanish, French, Hindi)
- [ ] Ingredient shopping list export
- [ ] Photo recognition (OCR ingredient labels)
- [ ] Nutrition facts calculation
- [ ] Meal planning calendar
- [ ] Social sharing (share recipes with friends)
- [ ] iOS app (requires Apple Developer account $99/year)
- [ ] Voice profile customization (different TTS voices)
- [ ] Offline mode with cached recipes

### Scalability Roadmap
- At 100 users: All free tiers sufficient
- At 500 users: May need LiveKit paid plan
- At 1,000+ users: Consider Supabase Pro, dedicated infrastructure
- Web/token server: Scales infinitely on Cloudflare (always free)

---

## 13. Testing & Quality

### Automated Testing
- **Acceptance Tests:** 7 voice scenarios (100% pass rate)
- **Benchmark Harness:** 30-trial kitchen simulation
- **Latency Monitoring:** Live metrics collection
- **Idle Sweep:** 24 trials across 8 idle durations

### Manual Testing Checklist
- [ ] Sign in via Google OAuth
- [ ] Browse recipes (search, filter)
- [ ] Start cooking session
- [ ] Voice commands (navigation, timers, substitutions)
- [ ] Multi-timer disambiguation
- [ ] Allergy safety checks
- [ ] Session end with active timers
- [ ] Favorites sync across devices
- [ ] Recently viewed updates
- [ ] APK installation on Android

---

## 14. Known Limitations

**Rate Limits:**
- Groq free tier: 7,000 ITPM, 200k tokens/day
- LiveKit free tier: 1,000 session minutes/month
- Deepgram: $200 credit (~45 hours transcription)

**Platform Support:**
- Android: Full support via APK
- iOS: Requires Apple Developer account ($99/year) for TestFlight
- Web: Full support on modern browsers

**Network Requirements:**
- Stable internet required (4G/WiFi)
- High bandwidth for WebRTC (Opus audio)
- ~150-250ms baseline network latency (geographic)

**Voice Recognition:**
- Optimized for English (US/UK)
- May struggle with heavy accents
- Noisy kitchens can affect VAD accuracy

**AI Recipe Generation:**
- Unverified recipes (safety disclaimer shown)
- May hallucinate ingredients/steps
- User must double-check critical values

---

## 15. Support & Documentation

**Key Documents:**
- `README.md` - Project overview
- `DEPLOYMENT_ARCHITECTURE.md` - Infrastructure guide
- `FREE_DEPLOYMENT.md` - Step-by-step deployment
- `RIME_EVIDENCE.md` - Performance benchmarks
- `mobile/README.md` - Mobile app details
- `docs/favorites-implementation.md` - Favorites system
- `docs/supabase-migration-favorites.sql` - Database migration

**Quick Links:**
- LiveKit Docs: https://docs.livekit.io
- Supabase Docs: https://supabase.com/docs
- Flutter Docs: https://docs.flutter.dev
- Rime API: https://rime.ai/docs

---

**Last Updated:** 2026-09-08  
**Version:** Phase M6 Complete  
**Total Cost:** $0 (100% FREE deployment) ✅
