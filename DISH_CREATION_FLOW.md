# Complete Dish Creation & Storage Flow

## Overview
Dishes in CookTalk can be created in multiple ways and stored in multiple places. Here's the complete flow.

## 1. Dish Creation Sources

### A. Curated/Verified Dishes (Hand-Authored)
**Location**: Hardcoded in multiple places
- `supabase/schema.sql` - Initial seed data
- `mobile/lib/services/supabase_service.dart` - `_seedDishes` static list
- `agent/recipes.json` - For voice agent access

**Properties**:
- `verified: true`
- `source: "curated"`
- Manually selected high-quality images
- Thoroughly tested recipes

**Examples**: 
- scrambled_eggs
- cacio_e_pepe
- ribeye_steak

### B. AI-Generated Dishes (User-Created)
**Flow**: User requests → Server generates → Saved to multiple locations

**Trigger Points**:
1. Mobile app: Search for non-existent dish
2. Direct API call: `POST /api/generate-dish`

## 2. AI Generation Flow (Step-by-Step)

### Request Flow

```
[Mobile App] 
    ↓ User searches "Chicken Tikka Masala"
    ↓ Not found in local cache
    ↓
[SupabaseService.generateDishViaServer()]
    ↓ HTTP POST to token server
    ↓
[Token Server: /api/generate-dish]
    ↓
    ├─ STEP 1: Check agent/recipes.json (existing recipes)
    ├─ STEP 2: Check agent/generated_dishes.json (cache)
    ├─ STEP 3: Rate limit check (15 req/min)
    ├─ STEP 4: Call Groq LLM (qwen3.8-27b)
    │    └─ Generate complete recipe JSON
    ├─ STEP 5: Fetch dish-specific image (Pexels/Unsplash)
    ├─ STEP 6: Save to local files
    │    ├─ agent/generated_dishes.json
    │    └─ agent/recipes.json (for voice agent)
    └─ STEP 7: Return complete dish JSON
    ↓
[Mobile App receives dish]
    ↓
[SupabaseService] Saves to Supabase
    ↓ INSERT INTO dishes table
    └─ With user_id + created_at
```

### Code Locations

**1. Token Server Generation** (`web/token_server.py:145-390`)
```python
@app.post("/api/generate-dish")
def generate_dish(req: GenerateDishRequest):
    # 1. Dedup checks
    # 2. LLM generation via Groq
    # 3. Image fetching
    # 4. Save to JSON files
    # 5. Return dish payload
```

**2. Mobile App Storage** (`mobile/lib/services/supabase_service.dart:580-620`)
```dart
Future<Dish> generateDishViaServer(String query, String serverUrl) async {
    // 1. Call token server /api/generate-dish
    // 2. Parse response
    // 3. Save to Supabase dishes table with user_id
    // 4. Fallback: Cache locally if Supabase unavailable
}
```

## 3. Storage Locations

### Primary Storage (Database)

#### Supabase `dishes` Table
**Schema** (`supabase/schema.sql:28-46`):
```sql
CREATE TABLE public.dishes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL,  -- breakfast, lunch, dinner, etc.
    cuisine TEXT NOT NULL,
    prep_time_minutes INT NOT NULL,
    cook_time_minutes INT NOT NULL,
    servings INT NOT NULL,
    difficulty TEXT NOT NULL,
    image_url TEXT NOT NULL,
    is_trending BOOLEAN DEFAULT FALSE,
    ingredients JSONB NOT NULL,
    steps JSONB NOT NULL,
    substitutions JSONB DEFAULT '{}',
    tags TEXT[],
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Access Control** (RLS Policies):
- ✅ **SELECT**: Public (everyone can view all dishes)
- ✅ **INSERT**: Authenticated users only
- ❌ **UPDATE/DELETE**: Not allowed (dishes are immutable)

**Important Note**: 
The schema shown above does NOT include `user_id`, but the mobile app tries to save it:
```dart
dishData['user_id'] = _currentProfile!.id;  // Line 598
```

**Migration Needed**: Add `user_id` column to track dish ownership:
```sql
ALTER TABLE public.dishes 
ADD COLUMN user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;

CREATE INDEX idx_dishes_user_id ON public.dishes(user_id);
```

### Secondary Storage (JSON Files)

#### 1. `agent/generated_dishes.json`
**Purpose**: Cache for quick lookups, deduplication
**Structure**:
```json
{
  "chicken-tikka-masala": {
    "id": "chicken-tikka-masala",
    "title": "Chicken Tikka Masala",
    "ingredients": [...],
    "steps": [...],
    // Full dish object
  }
}
```

**Updated By**: `web/token_server.py:96-99` (`save_generated_dish()`)

#### 2. `agent/recipes.json`
**Purpose**: Voice agent recipe database (for hands-free cooking)
**Structure**: Similar to generated_dishes.json but with voice-agent-specific fields
**Updated By**: `web/token_server.py:100-117` (`save_generated_dish()`)

### Tertiary Storage (In-Memory Fallback)

#### `SupabaseService._dynamicDishes` (Dart)
**Purpose**: In-memory cache when Supabase unavailable
**Type**: `List<Dish>`
**Location**: `mobile/lib/services/supabase_service.dart:39`

## 4. Data Flow Diagram

```
USER REQUEST: "Chicken Tikka Masala"
    │
    ↓
┌───────────────────────────────────────┐
│ Token Server (/api/generate-dish)    │
├───────────────────────────────────────┤
│ 1. Check recipes.json (existing)     │ → Return if found
│ 2. Check generated_dishes.json       │ → Return if found
│ 3. Generate via Groq LLM             │ → New recipe created
│ 4. Fetch image (Pexels/Unsplash)     │ → Image URL obtained
│ 5. Save to JSON files:               │
│    • agent/generated_dishes.json     │
│    • agent/recipes.json              │
│ 6. Return dish JSON to mobile app    │
└───────────────────────────────────────┘
    │
    ↓
┌───────────────────────────────────────┐
│ Mobile App (SupabaseService)         │
├───────────────────────────────────────┤
│ 7. Receive dish JSON                  │
│ 8. Save to Supabase:                  │
│    INSERT INTO dishes (               │
│      slug, title, ingredients,        │
│      steps, image_url, user_id, ...   │
│    )                                  │
│ 9. If Supabase fails:                 │
│    Cache in _dynamicDishes list       │
└───────────────────────────────────────┘
    │
    ↓
┌───────────────────────────────────────┐
│ STORED IN 3 PLACES:                   │
├───────────────────────────────────────┤
│ ✅ Supabase dishes table (primary)    │
│ ✅ agent/generated_dishes.json        │
│ ✅ agent/recipes.json (voice access)  │
└───────────────────────────────────────┘
```

## 5. Important Fields

### Dish Model Fields

| Field              | Type   | Required | Notes                           |
|--------------------|--------|----------|---------------------------------|
| id                 | String | ✅       | Kebab-case, unique              |
| slug               | String | ✅       | Same as id, unique constraint   |
| title              | String | ✅       | Display name                    |
| description        | String | ✅       | 1-2 sentence overview           |
| category           | String | ✅       | breakfast/lunch/dinner/etc      |
| cuisine            | String | ✅       | Italian/Indian/Mexican/etc      |
| prep_time_minutes  | Int    | ✅       | Prep time                       |
| cook_time_minutes  | Int    | ✅       | Cook time                       |
| servings           | Int    | ✅       | Number of servings              |
| difficulty         | String | ✅       | Easy/Medium/Hard                |
| image_url          | String | ✅       | Dish photo URL                  |
| is_trending        | Bool   | ✅       | Featured flag (default: false)  |
| verified           | Bool   | ✅       | Hand-authored flag              |
| source             | String | ✅       | "curated" or "ai_generated"     |
| ingredients        | JSONB  | ✅       | Array of {name, quantity, unit} |
| steps              | JSONB  | ✅       | Array of {step, instruction}    |
| substitutions      | JSONB  | ⚠️       | Map of ingredient → substitute  |
| user_id            | UUID   | ⚠️       | **MISSING FROM SCHEMA**         |
| created_at         | Time   | ✅       | Auto-generated                  |

⚠️ **Schema Issue**: `user_id` is saved by mobile app but doesn't exist in schema!

## 6. Deduplication Strategy

To avoid generating the same dish twice:

### Check 1: Existing Recipes
```python
# Normalize: "Chicken Tikka Masala" → "chicken tikka masala"
# Check recipes.json for fuzzy match
```

### Check 2: Generated Dishes Cache
```python
# Check generated_dishes.json
# Compare normalized names
```

### Check 3: Rate Limiting
```python
# Max 15 generations per minute
# Prevents abuse
```

## 7. Voice Agent Integration

When a dish is generated, it's automatically added to `agent/recipes.json` so the voice agent can:
- Read ingredients
- Guide through steps
- Set timers
- Suggest substitutions

**No restart required** - The agent dynamically loads recipes.

## 8. Known Issues & Recommendations

### Issue 1: Missing user_id Column
**Problem**: Mobile app saves `user_id` but column doesn't exist in schema
**Impact**: INSERT fails silently, falls back to local cache
**Fix**: 
```sql
ALTER TABLE public.dishes ADD COLUMN user_id UUID REFERENCES public.profiles(id);
```

### Issue 2: No Dish Ownership Tracking
**Problem**: Can't distinguish user's own AI dishes from others'
**Impact**: Security/privacy concerns, can't implement "My Dishes" feature
**Fix**: Add user_id + update RLS policies

### Issue 3: Dishes Are Immutable
**Problem**: No UPDATE/DELETE policies
**Impact**: Can't edit or remove generated dishes
**Fix**: Add policies for users to manage their own dishes

### Issue 4: Dual Storage Complexity
**Problem**: Dishes stored in both database AND JSON files
**Impact**: Potential sync issues, complexity
**Recommendation**: Use Supabase as source of truth, remove JSON caching

## 9. Testing the Flow

### Generate a New Dish
```bash
# Start token server
cd web
python token_server.py

# Generate dish
curl -X POST http://localhost:8000/api/generate-dish \
  -H "Content-Type: application/json" \
  -d '{"dish_name": "Pad Thai"}'

# Check it was saved
cat ../agent/generated_dishes.json  # Should contain pad-thai
cat ../agent/recipes.json           # Should contain pad-thai
```

### Check Supabase Storage
```sql
-- Connect to Supabase
SELECT id, slug, title, verified, source, created_at 
FROM dishes 
WHERE source = 'ai_generated' 
ORDER BY created_at DESC;
```

## 10. Future Improvements

1. **Add user_id column** to track dish ownership
2. **Implement dish editing** for user's own AI dishes
3. **Add dish rating/reviews** system
4. **Implement dish sharing** between users
5. **Add image upload** for user photos
6. **Cache popular dishes** to reduce API calls
7. **Add nutrition info** from USDA API
8. **Implement dish collections** (meal plans)

## Summary

**Dish Creation**: User request → Token server (Groq LLM) → JSON files → Supabase database

**Storage**: 
- Primary: Supabase `dishes` table
- Cache: `agent/generated_dishes.json` + `agent/recipes.json`
- Fallback: In-memory `_dynamicDishes` list

**Key Files**:
- `web/token_server.py` - Generation logic
- `mobile/lib/services/supabase_service.dart` - Storage logic
- `supabase/schema.sql` - Database schema
