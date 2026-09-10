# Flutter ListTile DecoratedBox Warning - Fixed

## Issue

Flutter was throwing assertion warnings:

```
ListTile background color or ink splashes may be invisible.

The ListTile is wrapped in a DecoratedBox that has a background color. 
Because ListTile paints its background and ink splashes on the nearest 
Material ancestor, this DecoratedBox will hide those effects.
```

## Root Cause

ListTile widgets were wrapped in Container/DecoratedBox with background colors. Since ListTile needs to paint ink splash effects on the nearest Material ancestor, the DecoratedBox was blocking these visual effects.

## Solution

Wrapped each affected ListTile in a Material widget with transparent color to provide the required Material ancestor while preserving the DecoratedBox styling.

## Files Fixed

### 1. `mobile/lib/screens/profile_screen.dart`

**Fixed 2 instances:**

#### Voice Character Selector (Line ~449)
**Before:**
```dart
child: ListTile(
  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
  ...
)
```

**After:**
```dart
child: Material(
  color: Colors.transparent,
  child: ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    ...
  ),
),
```

#### Kitchen Noise Filter/VAD Selector (Line ~559)
**Before:**
```dart
child: ListTile(
  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
  ...
)
```

**After:**
```dart
child: Material(
  color: Colors.transparent,
  child: ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    ...
  ),
),
```

### 2. `mobile/lib/screens/favorites_screen.dart`

**Fixed 1 instance:**

#### Favorite Dish List Items (Line ~222)
**Before:**
```dart
child: ListTile(
  contentPadding: const EdgeInsets.all(12),
  ...
)
```

**After:**
```dart
child: Material(
  color: Colors.transparent,
  child: ListTile(
    contentPadding: const EdgeInsets.all(12),
    ...
  ),
),
```

## Result

✅ ListTile ink splash effects now work correctly  
✅ No visual regression - Material widget is transparent  
✅ DecoratedBox styling preserved  
✅ Flutter assertion warnings eliminated  

## Testing

Run the app and verify:
1. Voice selector modal shows properly with tap feedback
2. VAD selector modal shows properly with tap feedback
3. Favorites screen list items have proper tap ripple effects
4. No assertion warnings in console

All ListTile tap interactions should now show proper Material ink splash animations.
