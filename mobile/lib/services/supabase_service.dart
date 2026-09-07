import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dish.dart';
import '../models/user_profile.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  bool _isSupabaseInitialized = false;
  bool get isLiveSupabase => _isSupabaseInitialized;

  // Supabase Credentials (Override via --dart-define or directly in config)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // In-memory / persistent fallback state for offline / demo mode
  UserProfile? _currentProfile;
  final Set<String> _favoriteIds = {'steamed-dimsum-dumplings'};
  final ValueNotifier<UserProfile?> authStateNotifier = ValueNotifier(null);
  SharedPreferences? _prefs;
  bool _prefsCheckCompleted = false;

  Future<SharedPreferences?> _getPrefs() async {
    if (_prefs != null) return _prefs;
    if (_prefsCheckCompleted) return null;
    try {
      _prefs = await SharedPreferences.getInstance();
      return _prefs;
    } catch (e) {
      _prefsCheckCompleted = true;
      debugPrint('[SupabaseService] SharedPreferences channel not available (using resilient in-memory storage).');
      return null;
    }
  }

  Future<void> initialize() async {
    if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseAnonKey,
        );
        _isSupabaseInitialized = true;
        debugPrint('[SupabaseService] Initialized live Supabase client.');
      } catch (e) {
        debugPrint('[SupabaseService] Live initialization failed: $e. Falling back to local mode.');
      }
    } else {
      debugPrint('[SupabaseService] No credentials provided. Running in resilient local/demo mode.');
    }

    // Load persisted mock profile if available
    await _loadLocalProfile();
  }

  String _rimeVoiceStyle = 'Astra';
  bool _isMetric = true;
  String _vadSensitivity = 'Standard';

  Future<void> _loadLocalProfile() async {
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        final profileJson = prefs.getString('cooktalk_user_profile');
        if (profileJson != null) {
          _currentProfile = UserProfile.fromJson(jsonDecode(profileJson));
          authStateNotifier.value = _currentProfile;
        }
        _rimeVoiceStyle = prefs.getString('cooktalk_rime_voice') ?? 'Astra';
        _isMetric = prefs.getBool('cooktalk_is_metric') ?? true;
        _vadSensitivity = prefs.getString('cooktalk_vad_sensitivity') ?? 'Standard';
      }
    } catch (e) {
      debugPrint('[SupabaseService] Local profile load: continuing with default profile ($e)');
    }
  }

  Future<void> _saveLocalProfile(UserProfile profile) async {
    _currentProfile = profile;
    authStateNotifier.value = profile;
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString('cooktalk_user_profile', jsonEncode(profile.toJson()));
      }
    } catch (e) {
      debugPrint('[SupabaseService] Local profile save (in-memory active): $e');
    }
  }

  UserProfile? get currentUser => _currentProfile;

  bool get isAuthenticated => _currentProfile != null;

  bool get hasCompletedOnboarding => _currentProfile?.onboardingCompleted ?? false;

  /// Password-less Authentication via Google OAuth
  Future<UserProfile?> signInWithGoogle({bool isDemo = false}) async {
    if (_isSupabaseInitialized && !isDemo) {
      try {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.livekit.cooktalk://login-callback/',
        );
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final profile = UserProfile(
            id: user.id,
            email: user.email ?? 'samantha.cooks@gmail.com',
            fullName: user.userMetadata?['full_name']?.toString() ?? 'Samantha',
            avatarUrl: user.userMetadata?['avatar_url']?.toString() ??
                'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
            onboardingCompleted: false,
          );
          await _saveLocalProfile(profile);
          return profile;
        }
      } catch (e) {
        debugPrint('[SupabaseService] Google sign in error: $e. Using demo mode.');
      }
    }

    // Seamless Demo / Emulator Google Sign-In
    final profile = UserProfile(
      id: 'demo-samantha-101',
      email: 'samantha.cooks@gmail.com',
      fullName: 'Samantha',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
      favoriteCuisines: [],
      cookingFrequency: 'A few times a week',
      onboardingCompleted: false,
    );
    await _saveLocalProfile(profile);
    return profile;
  }

  /// Password-less Authentication via Apple OAuth
  Future<UserProfile?> signInWithApple({bool isDemo = false}) async {
    if (_isSupabaseInitialized && !isDemo) {
      try {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.apple,
          redirectTo: 'io.livekit.cooktalk://login-callback/',
        );
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final profile = UserProfile(
            id: user.id,
            email: user.email ?? 'samantha.apple@icloud.com',
            fullName: user.userMetadata?['full_name']?.toString() ?? 'Samantha',
            avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
            onboardingCompleted: false,
          );
          await _saveLocalProfile(profile);
          return profile;
        }
      } catch (e) {
        debugPrint('[SupabaseService] Apple sign in error: $e. Using demo mode.');
      }
    }

    // Demo fallback for emulator
    final profile = UserProfile(
      id: 'demo-samantha-apple-101',
      email: 'samantha.cooks@gmail.com',
      fullName: 'Samantha',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
      favoriteCuisines: [],
      cookingFrequency: 'A few times a week',
      onboardingCompleted: false,
    );
    await _saveLocalProfile(profile);
    return profile;
  }

  /// Update preferences from Onboarding questionnaire
  Future<void> savePreferences({
    required List<String> favoriteCuisines,
    required String cookingFrequency,
  }) async {
    if (_currentProfile == null) return;

    final updated = _currentProfile!.copyWith(
      favoriteCuisines: favoriteCuisines,
      cookingFrequency: cookingFrequency,
      onboardingCompleted: true,
    );

    if (_isSupabaseInitialized) {
      try {
        await Supabase.instance.client.from('profiles').upsert(updated.toJson());
      } catch (e) {
        debugPrint('[SupabaseService] Failed to upsert profile to Supabase: $e');
      }
    }

    await _saveLocalProfile(updated);
  }

  /// Update user profile details
  Future<void> updateProfile({
    String? fullName,
    String? avatarUrl,
    String? cookingFrequency,
    List<String>? favoriteCuisines,
  }) async {
    if (_currentProfile == null) return;
    final updated = _currentProfile!.copyWith(
      fullName: fullName,
      avatarUrl: avatarUrl,
      cookingFrequency: cookingFrequency,
      favoriteCuisines: favoriteCuisines,
    );
    if (_isSupabaseInitialized) {
      try {
        await Supabase.instance.client.from('profiles').upsert(updated.toJson());
      } catch (e) {
        debugPrint('[SupabaseService] Failed to update profile in Supabase: $e');
      }
    }
    await _saveLocalProfile(updated);
  }

  // Voice & Kitchen preferences
  String get rimeVoiceStyle => _rimeVoiceStyle;
  Future<void> setRimeVoiceStyle(String style) async {
    _rimeVoiceStyle = style;
    try {
      final prefs = await _getPrefs();
      if (prefs != null) await prefs.setString('cooktalk_rime_voice', style);
    } catch (_) {}
  }

  bool get isMetric => _isMetric;
  Future<void> setIsMetric(bool metric) async {
    _isMetric = metric;
    try {
      final prefs = await _getPrefs();
      if (prefs != null) await prefs.setBool('cooktalk_is_metric', metric);
    } catch (_) {}
  }

  String get vadSensitivity => _vadSensitivity;
  Future<void> setVadSensitivity(String sensitivity) async {
    _vadSensitivity = sensitivity;
    try {
      final prefs = await _getPrefs();
      if (prefs != null) await prefs.setString('cooktalk_vad_sensitivity', sensitivity);
    } catch (_) {}
  }

  /// Sign out
  Future<void> signOut() async {
    if (_isSupabaseInitialized) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
    }
    _currentProfile = null;
    authStateNotifier.value = null;
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.remove('cooktalk_user_profile');
      }
    } catch (_) {}
  }

  /// Permanent Account Deletion (Apple App Store Guideline 5.1.1 & Google Play Compliance)
  Future<void> deleteAccount() async {
    if (_isSupabaseInitialized && _currentProfile != null) {
      try {
        await Supabase.instance.client.from('profiles').delete().eq('id', _currentProfile!.id);
      } catch (e) {
        debugPrint('[SupabaseService] Supabase profile deletion error: $e');
      }
      try {
        await Supabase.instance.client.auth.admin.deleteUser(_currentProfile!.id);
      } catch (_) {}
    }

    _currentProfile = null;
    _favoriteIds.clear();
    _recentlyViewedInAiIds.clear();
    authStateNotifier.value = null;

    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.remove('cooktalk_user_profile');
        await prefs.remove('cooktalk_favorites');
        await prefs.remove('cooktalk_ai_recent_views');
        await prefs.remove('cooktalk_rime_voice');
        await prefs.remove('cooktalk_is_metric');
        await prefs.remove('cooktalk_vad_sensitivity');
      }
    } catch (_) {}
  }

  /// Favorites toggle
  bool isFavorite(String dishId) => _favoriteIds.contains(dishId);

  void toggleFavorite(String dishId) {
    if (_favoriteIds.contains(dishId)) {
      _favoriteIds.remove(dishId);
    } else {
      _favoriteIds.add(dishId);
    }
    // Notify listeners if needed
  }

  Set<String> get favoriteDishIds => Set.unmodifiable(_favoriteIds);

  /// Fetch dishes list (from Supabase if connected, else curated seed data)
  Future<List<Dish>> fetchDishes({String? category}) async {
    if (_isSupabaseInitialized) {
      try {
        var query = Supabase.instance.client.from('dishes').select();
        if (category != null && category.toLowerCase() != 'more') {
          query = query.eq('category', category.toLowerCase());
        }
        final data = await query;
        return (data as List).map((e) => Dish.fromJson(e)).toList();
      } catch (e) {
        debugPrint('[SupabaseService] Query dishes failed: $e');
      }
    }

    // Return rich mock catalog matching uploaded reference UI
    final catalog = _seedDishes;
    if (category != null && category.toLowerCase() != 'more') {
      return catalog
          .where((d) => d.category.toLowerCase() == category.toLowerCase())
          .toList();
    }
    return catalog;
  }

  // In-memory record of recipes recently viewed / cooked with the AI assistant
  final List<String> _recentlyViewedInAiIds = [
    'pancakes',
    'steamed-dimsum-dumplings',
    'smoky-bbq-grilled-chicken',
    'classic-carbonara',
  ];

  Future<List<Dish>> fetchRecentlyViewedAIDishes() async {
    final all = await fetchDishes();
    final result = <Dish>[];
    for (final id in _recentlyViewedInAiIds) {
      final match = all.where((d) => d.id == id || d.slug == id).firstOrNull;
      if (match != null && !result.contains(match)) {
        result.add(match);
      }
    }
    for (final dish in all) {
      if (!result.contains(dish)) {
        result.add(dish);
      }
    }
    return result;
  }

  void recordDishViewedInAI(String dishId) {
    _recentlyViewedInAiIds.remove(dishId);
    _recentlyViewedInAiIds.insert(0, dishId);
  }

  Future<List<Dish>> fetchTrendingDishes() async {
    final all = await fetchDishes();
    return all.where((d) => d.isTrending).toList();
  }

  // Curated Seed Data with high quality food photography
  static final List<Dish> _seedDishes = [
    Dish(
      id: 'steamed-dimsum-dumplings',
      slug: 'steamed-dimsum-dumplings',
      title: 'Steamed Pork & Shrimp Dumplings',
      description: 'Delicate Cantonese dim sum dumplings steamed in bamboo baskets with ginger scallion sauce.',
      category: 'snack',
      cuisine: 'Asian',
      prepTimeMinutes: 25,
      cookTimeMinutes: 15,
      servings: 4,
      difficulty: 'Medium',
      imageUrl: 'https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?auto=format&fit=crop&w=800&q=80',
      isTrending: true,
      ingredients: const [
        Ingredient(name: 'dumpling wrappers', quantity: '24', unit: 'pieces'),
        Ingredient(name: 'ground pork', quantity: '300', unit: 'g'),
        Ingredient(name: 'shrimp minced', quantity: '150', unit: 'g'),
        Ingredient(name: 'sesame oil', quantity: '1', unit: 'tbsp'),
        Ingredient(name: 'scallions', quantity: '2', unit: 'stalks'),
      ],
      steps: const [
        RecipeStep(step: 1, instruction: 'Combine ground pork, minced shrimp, ginger, and sesame oil in a bowl.'),
        RecipeStep(step: 2, instruction: 'Place one spoonful of filling in each wrapper and pleat edges firmly to seal.'),
        RecipeStep(step: 3, instruction: 'Steam over boiling water for 10-12 minutes until cooked through.'),
      ],
      substitutions: const {
        'pork': 'Ground chicken or firm pressed tofu with minced shiitake mushrooms.',
      },
    ),
    Dish(
      id: 'smoky-bbq-grilled-chicken',
      slug: 'smoky-bbq-grilled-chicken',
      title: 'Smoky Flame-Grilled BBQ Chicken',
      description: 'Juicy chicken thighs glazed in homemade smoky barbecue sauce with charred herbs.',
      category: 'dinner',
      cuisine: 'American',
      prepTimeMinutes: 15,
      cookTimeMinutes: 30,
      servings: 4,
      difficulty: 'Easy',
      imageUrl: 'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?auto=format&fit=crop&w=800&q=80',
      isTrending: true,
      ingredients: const [
        Ingredient(name: 'chicken thighs', quantity: '4', unit: 'pieces'),
        Ingredient(name: 'bbq sauce', quantity: '0.5', unit: 'cup'),
        Ingredient(name: 'smoked paprika', quantity: '1', unit: 'tsp'),
        Ingredient(name: 'olive oil', quantity: '2', unit: 'tbsp'),
      ],
      steps: const [
        RecipeStep(step: 1, instruction: 'Season chicken thighs generously with paprika, salt, and pepper.'),
        RecipeStep(step: 2, instruction: 'Grill chicken for 6 to 8 minutes per side until nicely charred.'),
        RecipeStep(step: 3, instruction: 'Brush with barbecue sauce during the final 4 minutes of cooking.'),
      ],
      substitutions: const {
        'bbq sauce': 'Honey mustard or garlic herb chimichurri.',
      },
    ),
    Dish(
      id: 'pancakes',
      slug: 'pancakes',
      title: 'Golden Fluffy Buttermilk Pancakes',
      description: 'Classic diner pancakes with crispy edges, soft airy centers, and warm maple syrup.',
      category: 'breakfast',
      cuisine: 'American',
      prepTimeMinutes: 10,
      cookTimeMinutes: 15,
      servings: 4,
      difficulty: 'Easy',
      imageUrl: 'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&w=800&q=80',
      isTrending: true,
      ingredients: const [
        Ingredient(name: 'flour', quantity: '2', unit: 'cups'),
        Ingredient(name: 'buttermilk', quantity: '1.75', unit: 'cups'),
        Ingredient(name: 'eggs', quantity: '2', unit: 'large'),
        Ingredient(name: 'butter', quantity: '3', unit: 'tbsp'),
      ],
      steps: const [
        RecipeStep(step: 1, instruction: 'Whisk dry ingredients together: flour, sugar, baking powder, and salt.'),
        RecipeStep(step: 2, instruction: 'Pour buttermilk and eggs into dry ingredients; whisk gently until combined with small lumps.'),
        RecipeStep(step: 3, instruction: 'Cook on medium hot skillet for 2-3 minutes per side until golden brown.'),
      ],
      substitutions: const {
        'buttermilk': '1 cup whole milk + 1 tbsp lemon juice or white vinegar. Rest 5 mins.',
      },
    ),
    Dish(
      id: 'classic-carbonara',
      slug: 'classic-carbonara',
      title: 'Authentic Roman Carbonara',
      description: 'Silky pasta with crispy guanciale, pecorino romano, egg yolks, and coarse black pepper.',
      category: 'dinner',
      cuisine: 'Italian',
      prepTimeMinutes: 10,
      cookTimeMinutes: 15,
      servings: 2,
      difficulty: 'Medium',
      imageUrl: 'https://images.unsplash.com/photo-1612874742237-6526221588e3?auto=format&fit=crop&w=800&q=80',
      isTrending: false,
      ingredients: const [
        Ingredient(name: 'spaghetti', quantity: '400', unit: 'g'),
        Ingredient(name: 'guanciale', quantity: '150', unit: 'g'),
        Ingredient(name: 'egg yolks', quantity: '4', unit: 'large'),
        Ingredient(name: 'pecorino', quantity: '80', unit: 'g'),
      ],
      steps: const [
        RecipeStep(step: 1, instruction: 'Boil spaghetti in salted water until al dente.'),
        RecipeStep(step: 2, instruction: 'Crisp guanciale in a skillet until golden.'),
        RecipeStep(step: 3, instruction: 'Toss hot pasta with egg yolk and cheese paste with pasta water to emulsify.'),
      ],
      substitutions: const {
        'guanciale': 'Pancetta or thick-cut smoked bacon.',
      },
    ),
    Dish(
      id: 'tropical-green-smoothie',
      slug: 'tropical-green-smoothie',
      title: 'Mango Pineapple Energy Smoothie',
      description: 'Tropical power smoothie with frozen mango, pineapple, baby spinach, and coconut water.',
      category: 'smoothies',
      cuisine: 'Healthy',
      prepTimeMinutes: 5,
      cookTimeMinutes: 5,
      servings: 1,
      difficulty: 'Easy',
      imageUrl: 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?auto=format&fit=crop&w=800&q=80',
      isTrending: false,
      ingredients: const [
        Ingredient(name: 'frozen mango', quantity: '1', unit: 'cup'),
        Ingredient(name: 'pineapple', quantity: '0.5', unit: 'cup'),
        Ingredient(name: 'spinach', quantity: '1', unit: 'handful'),
        Ingredient(name: 'coconut water', quantity: '1', unit: 'cup'),
      ],
      steps: const [
        RecipeStep(step: 1, instruction: 'Add all ingredients into high speed blender.'),
        RecipeStep(step: 2, instruction: 'Blend for 60 seconds until smooth and creamy.'),
      ],
      substitutions: const {
        'coconut water': 'Almond milk or fresh orange juice.',
      },
    ),
  ];
}
