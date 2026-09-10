# CookTalk Mobile UI Fixes - Implementation Plan

## TASK 1: Fix Empty State Layout

### Current Issues (mobile/lib/main.dart):
1. **Line 1796**: Shows "Step 1 of 0" when _totalSteps = 0
2. **Line 1820**: Progress bar renders with value 0.0 (appears full in some themes)
3. **Line 1562**: stepProgress = 0.0 when totalSteps = 0
4. Missing: Conditional rendering for empty state vs active recipe state

### Fix Strategy:
```dart
// Wrap recipe card in conditional:
if (_totalSteps > 0) {
  // Show full recipe card with icon, step badge, progress
} else {
  // Show minimal empty state: just prompt text
}
```

---

## TASK 2: Emoji Sweep - Complete List

### Found in 5 files:

#### 1. `mobile/lib/main.dart`
**Lines 725-732**: Connecting messages
- 🔥 "Firing up the AI chef..."
- 🎙️ "Preheating your voice assistant..."
- 👨‍🍳 "Warming up the kitchen co-pilot..."
- ✨ "Preparing your sous-chef..."
- 🧠 "Loading culinary intelligence..."
- 🎯 "Activating voice recognition..."
- 🤖 "Connecting to cooking brain..."
- 🥘 "Getting ingredients ready..."

**Line 1215**: RegExp removes emojis from status display

#### 2. `mobile/lib/screens/profile_screen.dart`
**Lines 23-34**: Cuisine pool (_cuisinePool)
- 🍕 Italian, 🥢 Asian, 🌮 Mexican, 🍛 Indian
- 🫒 Mediterranean, 🍔 American, 🥐 French, 🍣 Japanese
- 🍜 Thai, 🧆 Middle Eastern, 🥗 Healthy/Clean, 🦐 Seafood

**Lines 56-67**: Allergy list (_commonAllergies)
- 🥛 Dairy, 🥚 Eggs, 🥜 Peanuts, 🌰 Tree Nuts
- 🫘 Soy, 🌾 Wheat, 🐟 Fish, 🦐 Shellfish
- 🫘 Sesame, 🍞 Gluten, 🧈 Lactose, 🌽 Corn

**Line 989**: Hardcoded "🥗" in favorite cuisines display

#### 3. `mobile/lib/screens/preferences_screen.dart`
**Lines 20-31**: Same cuisine list as profile_screen

#### 4. `mobile/lib/screens/about_screen.dart`
**Line 149**: "🎙️ Voice-Controlled Cooking" (appears twice)
**Line 233**: "Made with ❤️ for home chefs everywhere"

#### 5. `mobile/lib/screens/home_screen.dart`
**Line 510**: Comment "// Header Pill: [🎙️ VOICE ASSISTANT]" (appears twice)
**Line 572**: Comment "// Action Button: [ Start Cooking Assistant 🎙️ ]" (appears twice)
**Line 1741**: Hardcoded "✨" icon

### Replacement Strategy:
Replace all with Material Icons (Tabler-style already in use):
- 🔥 → Icons.local_fire_department
- 🎙️ → Icons.mic_rounded
- 👨‍🍳 → Icons.restaurant_menu
- ✨ → Icons.auto_awesome
- 🧠 → Icons.psychology
- 🎯 → Icons.adjust
- 🤖 → Icons.smart_toy
- 🥘 → Icons.dinner_dining
- ❤️ → Icons.favorite
- Food emojis → Icons.restaurant (or remove entirely for profile/prefs screens)

---

## TASK 3: Mystery Icons Explanation

### Icons Next to Hang-Up Button (Lines 1442-1478):

#### Icon 1: Sun (Icons.wb_sunny_rounded / wb_sunny_outlined)
**Location**: Lines 1442-1464
**Purpose**: **Screen Wakelock Toggle**
- When ON (filled sun): Screen stays awake during cooking
- When OFF (outlined sun): Screen can sleep normally
- **Status**: FUNCTIONAL, INTENTIONAL
- **Action**: Keep (it's useful), but consider UI clarity

#### Icon 2: Gauge/Speed (Icons.speed_rounded / speed_outlined)  
**Location**: Lines 1467-1478
**Purpose**: **Latency Demo Stats Toggle**
- Shows/hides performance metrics (TTS TTFB, E2E latency)
- Used for demo and debugging
- **Status**: DEBUG FEATURE
- **Action**: **REMOVE** in production or hide behind developer mode

### Small Badge Near "Getting ingredients ready"
**Need to identify this in screenshots - likely the cuisine/recipe type indicator**

---

## TASK 4: Remove Mic Circle, Keep Wave Primary

### Current State:
- Large circular mic button exists
- Amplitude-reactive wave bars sit underneath
- Wave should BE the primary visual

### Fix Required:
Find and remove:
1. Circular mic button Container/decoration
2. Mic icon (Icons.mic)
3. Keep only the amplitude bars as primary UI

### Search targets:
- "CircleAvatar" or circular mic decoration
- "Icons.mic" in listening/speaking state
- Wave/amplitude bar rendering code

---

## Next Steps:
1. Implement Task 1 fixes (empty state conditional)
2. Replace all emojis Task 2
3. Remove latency demo toggle (Task 3)
4. Find and remove mic circle (Task 4)
5. Take screenshots for proof
