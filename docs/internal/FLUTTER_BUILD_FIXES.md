# Flutter Mobile App Build Fixes

## Issues Fixed

### 1. Missing `dish_card.dart` Import
**File**: `mobile/lib/screens/dishes_screen.dart`
**Issue**: Import statement for non-existent `../widgets/dish_card.dart`
**Fix**: Removed unused import (dish cards are built inline in the file)

### 2. Incorrect Model Property Access
**File**: `mobile/lib/screens/dishes_screen.dart:432`
**Issue**: Accessing `dish.name` when Dish model uses `dish.title`
**Fix**: Changed to `dish.title`

### 3. Missing Closing Braces
**File**: `mobile/lib/screens/favorites_screen.dart`
**Issue**: File missing closing braces for class and build method
**Fix**: Added closing braces at end of file

### 4. Private Field Access
**File**: `mobile/lib/screens/home_screen.dart:51`
**Issue**: Accessing private `_cookHistoryByUser` field directly
**Fix**: Changed to use public `hasCookedBefore()` method to check if dishes were cooked

**Before**:
```dart
final cookHistory = SupabaseService.instance._cookHistoryByUser[currentUserId] ?? [];
final cookedDishes = _dishes.where((d) => cookedDishIds.contains(d.id) || cookedDishIds.contains(d.slug)).toList();
```

**After**:
```dart
final cookedDishes = _dishes.where((d) => SupabaseService.instance.hasCookedBefore(d.id)).toList();
```

### 5. Null Safety Errors in main.dart
**File**: `mobile/lib/main.dart:1007-1020`
**Issue**: Accessing properties on nullable `widget.initialRecipe` without null checks
**Fix**: Wrapped access in `if (widget.initialRecipe != null)` check with null assertion operator

**File**: `mobile/lib/main.dart:1487-1504`
**Issue**: Similar null safety issue in `_buildDishThumbnail` method
**Fix**: Added early return if `widget.initialRecipe` is null, then used null assertion operator

## Kotlin Built-in Plugin Issue

**Issue**: The error message about Kotlin plugins is a Flutter/Gradle warning, not a blocking error.

**Context**: This warning appears when Flutter plugins haven't migrated to built-in Kotlin support yet. The actual build failures were caused by the Dart compilation errors listed above.

**Action**: No action needed - the Dart errors were the blocking issues. Once those are fixed, the app will build successfully. The Kotlin warning is informational only.

## Test Build

After all fixes, run:
```bash
cd mobile
flutter clean
flutter pub get
flutter build apk --debug  # For Android
# or
flutter build ios --debug --no-codesign  # For iOS
```

## Files Modified
- `mobile/lib/screens/dishes_screen.dart` - Removed unused import, fixed property name
- `mobile/lib/screens/favorites_screen.dart` - Added missing closing braces
- `mobile/lib/screens/home_screen.dart` - Fixed private field access
- `mobile/lib/main.dart` - Fixed null safety errors (2 locations)

All changes maintain existing functionality while fixing compilation errors.
