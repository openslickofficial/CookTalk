# Favorites Implementation - CookTalk

## Overview
Implemented a persistent favorites system that stores favorite dish IDs as an array field in the user profile table.

---

## Database Schema Changes

### Migration Applied
```sql
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS favorites TEXT[] DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_profiles_favorites 
ON profiles USING GIN (favorites);
```

### Updated `profiles` Table Schema
| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | User identifier |
| `email` | String | User email |
| `full_name` | String | User's display name |
| `avatar_url` | String | Profile picture URL |
| `favorite_cuisines` | Array\<String\> | Preferred cuisines |
| `cooking_frequency` | String | Cooking habit |
| `onboarding_completed` | Boolean | Setup completion flag |
| `allergies` | Array\<String\> | Food allergies |
| **`favorites`** | **Array\<String\>** | **Favorite dish IDs (NEW)** |

---

## Model Changes

### UserProfile Model (`user_profile.dart`)

#### Added Field
```dart
final List<String> favorites;  // Array of favorite dish IDs
```

#### Updated Constructor
```dart
const UserProfile({
  required this.id,
  required this.email,
  required this.fullName,
  required this.avatarUrl,
  this.favoriteCuisines = const [],
  this.cookingFrequency = 'A few times a week',
  this.onboardingCompleted = false,
  this.allergies = const [],
  this.favorites = const [],  // NEW
});
```

#### Updated Methods
- `copyWith()` - Now includes `favorites` parameter
- `fromJson()` - Parses `favorites` array from JSON
- `toJson()` - Serializes `favorites` to JSON

---

## Service Layer Changes

### SupabaseService (`supabase_service.dart`)

#### New Methods

**1. Load Favorites from Profile**
```dart
void _loadFavoritesFromProfile() {
  _favoriteIds.clear();
  if (_currentProfile?.favorites != null) {
    _favoriteIds.addAll(_currentProfile!.favorites);
  }
}
```

**2. Sync Favorites to Supabase**
```dart
Future<void> _syncFavoritesToProfile() async {
  if (_currentProfile == null) return;

  final updated = _currentProfile!.copyWith(
    favorites: _favoriteIds.toList()
  );
  
  if (_isSupabaseInitialized) {
    await Supabase.instance.client
      .from('profiles')
      .update({'favorites': _favoriteIds.toList()})
      .eq('id', _currentProfile!.id);
  }

  await _saveLocalProfile(updated);
}
```

**3. Fetch Favorite Dishes**
```dart
Future<List<Dish>> fetchFavoriteDishes() async {
  final all = await fetchDishes();
  final favoriteIds = _currentProfile?.favorites ?? [];
  return all.where((d) => favoriteIds.contains(d.id)).toList();
}
```

#### Updated Methods

**toggleFavorite()** - Now syncs to database
```dart
void toggleFavorite(String dishId) async {
  if (_favoriteIds.contains(dishId)) {
    _favoriteIds.remove(dishId);
  } else {
    _favoriteIds.add(dishId);
  }
  await _syncFavoritesToProfile();  // Persist to Supabase
}
```

**_saveLocalProfile()** - Loads favorites on profile save
```dart
Future<void> _saveLocalProfile(UserProfile profile) async {
  _currentProfile = profile;
  authStateNotifier.value = profile;
  _loadFavoritesFromProfile();  // NEW: Load favorites
  // ... rest of implementation
}
```

**signInWithGoogle()** - Fetches existing profile with favorites
```dart
// Now fetches complete profile from Supabase
final profileData = await Supabase.instance.client
  .from('profiles')
  .select()
  .eq('id', user.id)
  .maybeSingle();

final profile = profileData != null
  ? UserProfile.fromJson(profileData)  // Includes favorites
  : UserProfile(...);
```

**Auth State Listener** - Loads favorites on sign-in
```dart
// Fetches full profile including favorites on OAuth sign-in
if (event == AuthChangeEvent.signedIn) {
  final profileData = await Supabase.instance.client
    .from('profiles')
    .select()
    .eq('id', user.id)
    .maybeSingle();
  // ... loads favorites via _saveLocalProfile()
}
```

---

## Data Flow

### 1. User Signs In
```
Google OAuth → Supabase Auth
  → Fetch profile from `profiles` table (includes favorites array)
  → _saveLocalProfile(profile)
  → _loadFavoritesFromProfile()
  → _favoriteIds Set populated
```

### 2. User Toggles Favorite
```
UI: Heart icon tapped
  → toggleFavorite(dishId)
  → Add/Remove from _favoriteIds Set
  → _syncFavoritesToProfile()
  → Update Supabase: profiles.favorites = [array]
  → Update local profile
  → Save to SharedPreferences
```

### 3. Fetch Favorite Dishes
```
fetchFavoriteDishes()
  → Get all user dishes: fetchDishes()
  → Filter by favorites array from profile
  → Return List<Dish>
```

### 4. App Restart
```
App Launch → initialize()
  → _loadLocalProfile()
  → Load profile from SharedPreferences
  → _loadFavoritesFromProfile()
  → _favoriteIds restored
```

---

## Benefits of This Approach

### ✅ Pros
1. **Simple Architecture** - Single table, no JOINs
2. **Fast Reads** - Favorites loaded with user profile
3. **Consistent Pattern** - Matches `favorite_cuisines` and `allergies`
4. **Atomic Updates** - Profile and favorites updated together
5. **Offline Support** - Cached in SharedPreferences
6. **Good for Scale** - Users typically favorite 10-50 dishes

### ⚠️ Limitations
1. No "favorited_at" timestamp tracking
2. Can't query "most favorited dishes globally"
3. Array operations require special Postgres syntax
4. Orphaned IDs if dishes deleted (need cleanup logic)

### 🎯 Perfect For CookTalk Because
- User-specific AI-generated dishes (small catalog per user)
- Simple favoriting UX (no advanced analytics needed)
- Low volume (< 100 favorites per user expected)

---

## Testing Checklist

- [ ] Run migration: `supabase-migration-favorites.sql`
- [ ] Sign in with Google OAuth
- [ ] Toggle favorite on a dish
- [ ] Verify favorites persisted in Supabase `profiles` table
- [ ] Restart app
- [ ] Verify favorites restored from SharedPreferences
- [ ] Call `fetchFavoriteDishes()` - verify filtered list
- [ ] Sign out → Sign in different user → Verify separate favorites
- [ ] Test with 0, 1, 10, 50 favorites

---

## Migration Instructions

### 1. Apply Database Migration
```bash
# Run in Supabase SQL Editor or via CLI
psql -h your-db-host -U postgres -d postgres -f docs/supabase-migration-favorites.sql
```

### 2. Verify Migration
```sql
-- Check column exists
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles' AND column_name = 'favorites';

-- Check index exists
SELECT indexname FROM pg_indexes 
WHERE tablename = 'profiles' AND indexname = 'idx_profiles_favorites';
```

### 3. Test Manually
```sql
-- Test adding favorites
UPDATE profiles 
SET favorites = ARRAY['dish-1', 'dish-2', 'dish-3']
WHERE email = 'test@example.com';

-- Verify
SELECT id, email, favorites FROM profiles WHERE email = 'test@example.com';
```

---

## API Reference

### SupabaseService Methods

#### `isFavorite(String dishId) → bool`
Check if a dish is favorited by current user.

#### `toggleFavorite(String dishId) → Future<void>`
Add or remove dish from favorites. Syncs to Supabase automatically.

#### `fetchFavoriteDishes() → Future<List<Dish>>`
Get all favorite dishes for current user.

#### `Set<String> get favoriteDishIds`
Get all favorite dish IDs as a Set.

---

## Files Modified

1. `mobile/lib/models/user_profile.dart` - Added `favorites` field
2. `mobile/lib/services/supabase_service.dart` - Added sync logic
3. `docs/supabase-migration-favorites.sql` - Database migration
4. `docs/favorites-implementation.md` - This documentation

---

## Next Steps

1. **Add Favorites Screen** - Dedicated UI to browse favorite dishes
2. **Analytics** - Track favorite counts (optional)
3. **Cleanup Job** - Remove deleted dish IDs from favorites arrays
4. **Export/Import** - Backup favorites for account migration

---

## Support

For questions or issues, refer to:
- Supabase Array Columns: https://supabase.com/docs/guides/database/arrays
- Flutter Supabase SDK: https://supabase.com/docs/reference/dart
- PostgreSQL Array Functions: https://www.postgresql.org/docs/current/functions-array.html
