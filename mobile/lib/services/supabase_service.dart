import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dish.dart';
import '../models/user_profile.dart';
import '../config/supabase_config.dart';

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

  // Per-user cook history: key = userId, value = list of CookHistoryItem
  final Map<String, List<CookHistoryItem>> _cookHistoryByUser = {};
  final ValueNotifier<int> cookHistoryNotifier = ValueNotifier(0);

  // Dynamic dishes added via generation or local creation
  final List<Dish> _dynamicDishes = [];

  // Cached static dish names
  List<String>? _cachedStaticDishNames;

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
    final url = SupabaseConfig.supabaseUrl;
    final anonKey = SupabaseConfig.supabaseAnonKey;
    if (url.isNotEmpty && anonKey.isNotEmpty) {
      try {
        await Supabase.initialize(
          url: url,
          publishableKey: anonKey,
        );
        _isSupabaseInitialized = true;
        debugPrint('[SupabaseService] Initialized live Supabase client.');

        // Listen to auth state changes for OAuth redirect callbacks
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
          final AuthChangeEvent event = data.event;
          final Session? session = data.session;
          if ((event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) && session != null) {
            final user = session.user;
            final fullName = user.userMetadata?['full_name']?.toString() ??
                user.userMetadata?['name']?.toString() ??
                user.email?.split('@').first ??
                'Samantha';
            final rawAvatar = user.userMetadata?['avatar_url']?.toString() ??
                user.userMetadata?['picture']?.toString();
            final avatarUrl = (rawAvatar != null &&
                    rawAvatar.isNotEmpty &&
                    !rawAvatar.contains('photo-1534528741775-53994a69daeb'))
                ? rawAvatar
                : SupabaseConfig.getDiceBearAvatar(fullName);

            // Fetch full profile from Supabase to get favorites
            try {
              final profileData = await Supabase.instance.client
                  .from('profiles')
                  .select()
                  .eq('id', user.id)
                  .maybeSingle();

              final profile = profileData != null
                  ? UserProfile.fromJson(profileData)
                  : UserProfile(
                      id: user.id,
                      email: user.email ?? 'user@cooktalk.app',
                      fullName: fullName,
                      avatarUrl: avatarUrl,
                      onboardingCompleted: _currentProfile?.onboardingCompleted ?? false,
                    );

              await _saveLocalProfile(profile);
              debugPrint('[SupabaseService] OAuth user signed in: ${profile.fullName}');
            } catch (e) {
              debugPrint('[SupabaseService] Failed to fetch profile, using basic info: $e');
              final profile = UserProfile(
                id: user.id,
                email: user.email ?? 'user@cooktalk.app',
                fullName: fullName,
                avatarUrl: avatarUrl,
                onboardingCompleted: _currentProfile?.onboardingCompleted ?? false,
              );
              await _saveLocalProfile(profile);
            }
          } else if (event == AuthChangeEvent.signedOut) {
            _currentProfile = null;
            _favoriteIds.clear();
            authStateNotifier.value = null;
          }
        });
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
          // Load favorites from profile
          _loadFavoritesFromProfile();
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
    // Load favorites from profile
    _loadFavoritesFromProfile();
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

  /// Social Authentication via Google OAuth with Supabase
  Future<UserProfile?> signInWithGoogle({bool isDemo = false}) async {
    if (_isSupabaseInitialized && !isDemo) {
      try {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: SupabaseConfig.authRedirectUrl,
          authScreenLaunchMode: LaunchMode.externalApplication,
        );
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final fullName = user.userMetadata?['full_name']?.toString() ??
              user.userMetadata?['name']?.toString() ??
              'Samantha';
          final rawAvatar = user.userMetadata?['avatar_url']?.toString() ??
              user.userMetadata?['picture']?.toString();
          final avatarUrl = (rawAvatar != null &&
                  rawAvatar.isNotEmpty &&
                  !rawAvatar.contains('photo-1534528741775-53994a69daeb'))
              ? rawAvatar
              : SupabaseConfig.getDiceBearAvatar(fullName);

          // Try to fetch existing profile with favorites
          try {
            final profileData = await Supabase.instance.client
                .from('profiles')
                .select()
                .eq('id', user.id)
                .maybeSingle();

            final profile = profileData != null
                ? UserProfile.fromJson(profileData)
                : UserProfile(
                    id: user.id,
                    email: user.email ?? 'user@cooktalk.app',
                    fullName: fullName,
                    avatarUrl: avatarUrl,
                    onboardingCompleted: false,
                  );

            await _saveLocalProfile(profile);
            return profile;
          } catch (e) {
            debugPrint('[SupabaseService] Failed to fetch profile: $e');
            final profile = UserProfile(
              id: user.id,
              email: user.email ?? 'user@cooktalk.app',
              fullName: fullName,
              avatarUrl: avatarUrl,
              onboardingCompleted: false,
            );
            await _saveLocalProfile(profile);
            return profile;
          }
        }
        return null;
      } catch (e) {
        debugPrint('[SupabaseService] Google sign in error: $e. Using demo mode.');
      }
    }

    // Seamless Demo / Fallback Google Sign-In with DiceBear avatar
    final profile = UserProfile(
      id: 'demo-samantha-101',
      email: 'samantha.cooks@gmail.com',
      fullName: 'Samantha',
      avatarUrl: SupabaseConfig.getDiceBearAvatar('Samantha'),
      favoriteCuisines: [],
      cookingFrequency: 'A few times a week',
      onboardingCompleted: false,
    );
    await _saveLocalProfile(profile);
    return profile;
  }

  /// Dummy Apple Authentication (as requested: dummy for now)
  Future<UserProfile?> signInWithApple({bool isDemo = true}) async {
    // Keep Continue with Apple as dummy for now with DiceBear avatar
    final profile = UserProfile(
      id: 'demo-samantha-apple-101',
      email: 'samantha.apple@icloud.com',
      fullName: 'Samantha',
      avatarUrl: SupabaseConfig.getDiceBearAvatar('Samantha'),
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

  /// Update user allergies for Allergy Safeguard
  Future<void> updateUserAllergies(List<String> allergies) async {
    if (_currentProfile == null) return;
    final updated = _currentProfile!.copyWith(allergies: allergies);
    if (_isSupabaseInitialized) {
      try {
        await Supabase.instance.client.from('profiles').upsert(updated.toJson());
      } catch (e) {
        debugPrint('[SupabaseService] Failed to update allergies in Supabase: $e');
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

  /// Request Account Deletion with 7-Day Grace Period
  /// User can cancel within 7 days or by logging in again
  Future<Map<String, dynamic>> requestAccountDeletion({String? reason}) async {
    if (!_isSupabaseInitialized || _currentProfile == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Call Supabase function to schedule deletion
      final response = await Supabase.instance.client.rpc(
        'request_account_deletion',
        params: {
          'p_user_id': _currentProfile!.id,
          'p_reason': reason,
        },
      );

      final result = response as Map<String, dynamic>;
      
      if (result['success'] == true) {
        // Update local profile to reflect scheduled deletion
        final scheduledAt = DateTime.parse(result['scheduled_deletion_at']);
        final updated = _currentProfile!.copyWith(
          // Note: deletion_scheduled_at would need to be added to UserProfile model
        );
        await _saveLocalProfile(updated);
        
        debugPrint('[SupabaseService] Account deletion scheduled for: $scheduledAt');
        return {
          'success': true,
          'scheduled_deletion_at': scheduledAt,
          'days_remaining': result['days_remaining'] ?? 7,
        };
      } else {
        throw Exception(result['error'] ?? 'Failed to schedule deletion');
      }
    } catch (e) {
      debugPrint('[SupabaseService] Request deletion error: $e');
      rethrow;
    }
  }

  /// Cancel Account Deletion Request
  Future<bool> cancelAccountDeletion() async {
    if (!_isSupabaseInitialized || _currentProfile == null) {
      return false;
    }

    try {
      final response = await Supabase.instance.client.rpc(
        'cancel_account_deletion',
        params: {'p_user_id': _currentProfile!.id},
      );

      final result = response as Map<String, dynamic>;
      
      if (result['success'] == true) {
        debugPrint('[SupabaseService] Account deletion cancelled successfully');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[SupabaseService] Cancel deletion error: $e');
      return false;
    }
  }

  /// Get Deletion Status (if scheduled)
  Future<Map<String, dynamic>?> getDeletionStatus() async {
    if (!_isSupabaseInitialized || _currentProfile == null) {
      return null;
    }

    try {
      final response = await Supabase.instance.client.rpc(
        'get_deletion_status',
        params: {'p_user_id': _currentProfile!.id},
      );

      final result = response as Map<String, dynamic>;
      
      if (result['deletion_scheduled'] == true) {
        return {
          'scheduled_deletion_at': DateTime.parse(result['scheduled_deletion_at']),
          'days_remaining': result['days_remaining'],
          'hours_remaining': result['hours_remaining'],
          'can_cancel': result['can_cancel'] ?? true,
          'reason': result['reason'],
        };
      }
      
      return null; // No deletion scheduled
    } catch (e) {
      debugPrint('[SupabaseService] Get deletion status error: $e');
      return null;
    }
  }

  /// Permanent Account Deletion (Apple App Store Guideline 5.1.1 & Google Play Compliance)
  /// DEPRECATED: Use requestAccountDeletion() instead for grace period
  @Deprecated('Use requestAccountDeletion() for 7-day grace period')
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
    _cookHistoryByUser.clear();
    cookHistoryNotifier.value++;
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

  /// Favorites
  Set<String> get favoriteDishIds => _favoriteIds;

  bool isFavorite(String dishId) => _favoriteIds.contains(dishId);

  /// Load favorites from current user profile into in-memory set
  void _loadFavoritesFromProfile() {
    _favoriteIds.clear();
    if (_currentProfile?.favorites != null) {
      _favoriteIds.addAll(_currentProfile!.favorites);
    }
  }

  /// Sync favorites back to user profile in Supabase
  Future<void> _syncFavoritesToProfile() async {
    if (_currentProfile == null) return;

    // Update profile with new favorites list
    final updated = _currentProfile!.copyWith(favorites: _favoriteIds.toList());
    
    if (_isSupabaseInitialized) {
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'favorites': _favoriteIds.toList()})
            .eq('id', _currentProfile!.id);
        debugPrint('[SupabaseService] Synced ${_favoriteIds.length} favorites to profile');
      } catch (e) {
        debugPrint('[SupabaseService] Failed to sync favorites to Supabase: $e');
      }
    }

    // Update local profile
    await _saveLocalProfile(updated);
  }

  void toggleFavorite(String dishId) async {
    if (_favoriteIds.contains(dishId)) {
      _favoriteIds.remove(dishId);
    } else {
      _favoriteIds.add(dishId);
    }
    // Sync to database
    await _syncFavoritesToProfile();
  }

  Future<void> recordDishViewedInAI(String dishId) => recordCookHistory(dishId);

  String get _activeUserId => _currentProfile?.id ?? 'guest_user';

  /// Check if the current user has cooked this dish before
  bool hasCookedBefore(String dishId) {
    final history = _cookHistoryByUser[_activeUserId];
    if (history == null) return false;
    return history.any((h) => h.dishId == dishId);
  }

  /// Get the timestamp of when this dish was last cooked
  DateTime? getLastCookedAt(String dishId) {
    final history = _cookHistoryByUser[_activeUserId];
    if (history == null) return null;
    final item = history.where((h) => h.dishId == dishId).firstOrNull;
    return item?.lastCookedAt;
  }

  /// Record that the current user cooked this dish
  Future<void> recordCookHistory(String dishId) async {
    final uid = _activeUserId;
    final now = DateTime.now();

    final userList = _cookHistoryByUser.putIfAbsent(uid, () => []);
    userList.removeWhere((h) => h.dishId == dishId);
    userList.insert(0, CookHistoryItem(userId: uid, dishId: dishId, lastCookedAt: now));
    cookHistoryNotifier.value++;

    if (_isSupabaseInitialized) {
      try {
        await Supabase.instance.client.from('cook_history').upsert({
          'user_id': uid,
          'dish_id': dishId,
          'last_cooked_at': now.toIso8601String(),
        });
      } catch (e) {
        debugPrint('[SupabaseService] Upsert cook_history error: $e');
      }
    }
  }

  /// Fetch recently viewed / cooked dishes for current user
  Future<List<Dish>> fetchRecentlyViewedAIDishes() async {
    final all = await fetchDishes();
    final uid = _activeUserId;
    final userHistory = _cookHistoryByUser[uid] ?? [];

    final result = <Dish>[];
    // 1. First add dishes from user's cook_history, most-recent-first
    for (final item in userHistory) {
      final match = all.where((d) => d.id == item.dishId || d.slug == item.dishId).firstOrNull;
      if (match != null && !result.any((r) => r.id == match.id)) {
        result.add(match);
      }
    }
    // 2. Fallback: if user has no cook history yet, seed with the verified curated dishes
    if (result.isEmpty) {
      for (final d in all) {
        if (d.verified && !result.any((r) => r.id == d.id)) {
          result.add(d);
        }
      }
    }
    return result;
  }

  /// Fetch favorite dishes for current user
  Future<List<Dish>> fetchFavoriteDishes() async {
    final all = await fetchDishes();
    final favoriteIds = _currentProfile?.favorites ?? [];
    return all.where((d) => favoriteIds.contains(d.id)).toList();
  }

  /// Fetch dishes list (ALL dishes globally shared, user_id as attribution only)
  Future<List<Dish>> fetchDishes({String? category}) async {
    List<Dish> catalog = [];
    if (_isSupabaseInitialized && _currentProfile != null) {
      try {
        // Query ALL dishes globally - user_id is attribution only, NOT a visibility gate
        var query = Supabase.instance.client
            .from('dishes')
            .select();
        
        if (category != null && category.toLowerCase() != 'more') {
          query = query.eq('category', category.toLowerCase());
        }
        
        final data = await query;
        catalog = (data as List).map((e) => Dish.fromJson(e)).toList();
        
        // Add any dynamic dishes created locally
        for (final dyn in _dynamicDishes) {
          if (!catalog.any((c) => c.id == dyn.id || c.normalizedName == dyn.normalizedName)) {
            catalog.add(dyn);
          }
        }
      } catch (e) {
        debugPrint('[SupabaseService] Query user dishes failed: $e');
        // Return empty list if query fails
        return [];
      }
    }
    // If Supabase not initialized or user not logged in, return empty
    return catalog;
  }

  /// Load static dish names asset (suggestion-only, zero network)
  Future<List<String>> loadStaticDishNames() async {
    if (_cachedStaticDishNames != null) return _cachedStaticDishNames!;
    try {
      final jsonStr = await rootBundle.loadString('assets/data/static_dish_names.json');
      final list = (jsonDecode(jsonStr) as List).map((e) => e.toString()).toList();
      _cachedStaticDishNames = list;
      return list;
    } catch (e) {
      debugPrint('[SupabaseService] Error loading static dish names: $e');
      return [];
    }
  }

  /// Call server-side generation endpoint for genuinely new dishes and save to Supabase
  Future<Dish> generateDishViaServer(String query, String serverUrl) async {
    final uri = Uri.parse('$serverUrl/api/generate-dish');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'dish_name': query}),
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception('Server generation failed (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final dish = Dish.fromJson(data);

    // Save to Supabase dishes table with user_id
    if (_isSupabaseInitialized && _currentProfile != null) {
      try {
        final dishData = dish.toJson();
        dishData['user_id'] = _currentProfile!.id;
        dishData['created_at'] = DateTime.now().toIso8601String();
        
        await Supabase.instance.client.from('dishes').insert(dishData);
        debugPrint('[SupabaseService] Saved generated dish to Supabase for user: ${_currentProfile!.id}');
      } catch (e) {
        debugPrint('[SupabaseService] Failed to save dish to Supabase: $e');
        // Cache locally as fallback
        if (!_dynamicDishes.any((d) => d.id == dish.id || d.normalizedName == dish.normalizedName)) {
          _dynamicDishes.add(dish);
        }
      }
    } else {
      // Cache locally in dynamic dishes if Supabase not available
      if (!_dynamicDishes.any((d) => d.id == dish.id || d.normalizedName == dish.normalizedName)) {
        _dynamicDishes.add(dish);
      }
    }

    return dish;
  }

  Future<List<Dish>> fetchTrendingDishes() async {
    final all = await fetchDishes();
    return all.where((d) => d.isTrending).toList();
  }

  String? getDishImageUrl(String recipeId) {
    try {
      final clean = recipeId.toLowerCase().replaceAll('-', '_').trim();
      final match = _seedDishes.firstWhere(
        (d) => d.id.toLowerCase() == clean || d.slug.toLowerCase() == clean || d.title.toLowerCase().contains(clean),
      );
      return match.imageUrl;
    } catch (_) {
      return null;
    }
  }

  // Curated Seed Data: ONLY the original 3 hand-authored recipes have verified: true
  static final List<Dish> _seedDishes = [
    // --- 1. ORIGINAL HAND-AUTHORED BENCHMARK RECIPE 1 ---
    Dish(
      id: 'scrambled_eggs',
      slug: 'scrambled_eggs',
      title: 'Classic French Soft-Curd Scrambled Eggs',
      description: 'Velvety, slow-cooked scrambled eggs with cold butter and fresh chives.',
      category: 'breakfast',
      cuisine: 'French',
      prepTimeMinutes: 5,
      cookTimeMinutes: 8,
      servings: 2,
      baseServings: 2,
      difficulty: 'Easy',
      imageUrl: 'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=800&q=80',
      isTrending: true,
      verified: true, // ORIGINAL HAND-AUTHORED
      source: 'curated',
      normalizedName: 'classic french softcurd scrambled egg',
      ingredients: const [
        Ingredient(name: 'eggs', quantity: '4', unit: 'large'),
        Ingredient(name: 'butter', quantity: '2', unit: 'tablespoons, cold and cubed'),
        Ingredient(name: 'heavy cream', quantity: '1', unit: 'tablespoon'),
        Ingredient(name: 'kosher salt', quantity: '0.5', unit: 'teaspoon'),
        Ingredient(name: 'fresh chives', quantity: '1', unit: 'tablespoon, finely chopped'),
      ],
      steps: const [
        RecipeStep(step: 1, instruction: 'Crack four eggs into a cold, unheated nonstick skillet and add two tablespoons of cubed cold butter.'),
        RecipeStep(step: 2, instruction: 'Place the pan over medium-low heat and continuously stir with a silicone spatula for two minutes until curds start forming.'),
        RecipeStep(step: 3, instruction: 'Pull the skillet off the heat for thirty seconds while continuing to stir to prevent overcooking.'),
        RecipeStep(step: 4, instruction: 'Return to low heat for sixty seconds until velvety curds set, then fold in one tablespoon of heavy cream, salt, and chives.'),
        RecipeStep(step: 5, instruction: 'Transfer immediately to a warm plate and serve soft and custardy.'),
      ],
      substitutions: const {
        'butter': 'Ghee or olive oil (1.5 tablespoons), but cold butter provides the creamiest emulsion.',
        'heavy cream': '1 tablespoon of whole milk, 1 tablespoon of creme fraiche, or 1 tablespoon of sour cream.',
        'chives': 'Finely minced scallion greens or fresh flat-leaf parsley.',
      },
    ),

    // --- 2. ORIGINAL HAND-AUTHORED BENCHMARK RECIPE 2 ---
    Dish(
      id: 'cacio_e_pepe',
      slug: 'cacio_e_pepe',
      title: 'Authentic Roman Cacio e Pepe',
      description: 'Minimalist pasta with freshly cracked black peppercorns and creamy Pecorino Romano emulsion.',
      category: 'dinner',
      cuisine: 'Italian',
      prepTimeMinutes: 5,
      cookTimeMinutes: 12,
      servings: 2,
      baseServings: 2,
      difficulty: 'Medium',
      imageUrl: 'https://images.unsplash.com/photo-1621996346565-e3d5d6281699?auto=format&fit=crop&w=800&q=80',
      isTrending: true,
      verified: true, // ORIGINAL HAND-AUTHORED
      source: 'curated',
      normalizedName: 'authentic roman cacio e pepe',
      ingredients: const [
        Ingredient(name: 'spaghetti', quantity: '250', unit: 'grams'),
        Ingredient(name: 'pecorino romano', quantity: '100', unit: 'grams, very finely grated on microplane'),
        Ingredient(name: 'whole black peppercorns', quantity: '1.5', unit: 'tablespoons, freshly toasted and cracked'),
        Ingredient(name: 'pasta water', quantity: '0.75', unit: 'cup, starchy water reserved from boiling'),
        Ingredient(name: 'salt', quantity: '1', unit: 'tablespoon for boiling water'),
      ],
      steps: const [
        RecipeStep(step: 1, instruction: 'Bring four cups of lightly salted water to a boil and cook spaghetti for eight minutes until very al dente.'),
        RecipeStep(step: 2, instruction: 'Toast cracked black pepper in a wide dry skillet over medium heat for one minute until fragrant.'),
        RecipeStep(step: 3, instruction: 'Ladle half a cup of hot starchy pasta water into the pepper skillet to create a simmering pepper broth.'),
        RecipeStep(step: 4, instruction: 'In a small bowl, whisk grated pecorino with a splash of warm pasta water until it forms a smooth paste.'),
        RecipeStep(step: 5, instruction: 'Transfer cooked pasta into the skillet, remove from heat completely, and vigorously toss with the pecorino cream for ninety seconds until silky.'),
      ],
      substitutions: const {
        'pecorino romano': 'A 50/50 blend of Parmigiano Reggiano and Pecorino, or pure aged Parmesan if Pecorino is unavailable.',
        'black peppercorns': 'Coarse freshly cracked black pepper, but toasting whole peppercorns gives the best flavor.',
        'spaghetti': 'Bucatini, tonnarelli, or thick rigatoni.',
      },
    ),

    // --- 3. ORIGINAL HAND-AUTHORED BENCHMARK RECIPE 3 ---
    Dish(
      id: 'ribeye_steak',
      slug: 'ribeye_steak',
      title: 'Reverse-Sear Thick-Cut Ribeye with Garlic-Herb Butter',
      description: 'A thick-cut ribeye salted, gently brought to temperature, and hard-seared with foaming herb butter.',
      category: 'dinner',
      cuisine: 'American',
      prepTimeMinutes: 10,
      cookTimeMinutes: 45,
      servings: 2,
      baseServings: 2,
      difficulty: 'Medium',
      imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&q=80',
      isTrending: true,
      verified: true, // ORIGINAL HAND-AUTHORED
      source: 'curated',
      normalizedName: 'reversesear thickcut ribeye with garlicherb butter',
      ingredients: const [
        Ingredient(name: 'ribeye steak', quantity: '1', unit: 'thick-cut (approx 1.5 inches, 500g)'),
        Ingredient(name: 'kosher salt', quantity: '1', unit: 'teaspoon for dry brining'),
        Ingredient(name: 'high-smoke oil', quantity: '1', unit: 'tablespoon (avocado or grapeseed)'),
        Ingredient(name: 'unsalted butter', quantity: '3', unit: 'tablespoons'),
        Ingredient(name: 'garlic cloves', quantity: '3', unit: 'cloves, lightly crushed'),
        Ingredient(name: 'fresh rosemary and thyme', quantity: '3', unit: 'sprigs each'),
      ],
      steps: const [
        RecipeStep(step: 1, instruction: 'Season the ribeye thoroughly on all sides with kosher salt and let it dry brine uncovered in the fridge for at least two hours.'),
        RecipeStep(step: 2, instruction: 'Bake on a wire rack at 225 degrees Fahrenheit for thirty minutes until internal temperature hits 115 degrees for medium rare.'),
        RecipeStep(step: 3, instruction: 'Heat a heavy cast iron skillet over high heat with one tablespoon of oil until smoking hot for three minutes.'),
        RecipeStep(step: 4, instruction: 'Sear the ribeye for one minute per side to develop a deep brown crust.'),
        RecipeStep(step: 5, instruction: 'Drop the heat, add butter, crushed garlic, and herbs, and spoon the foaming butter over the steak for two minutes.'),
        RecipeStep(step: 6, instruction: 'Rest the steak on a warm cutting board for ten minutes before carving.'),
      ],
      substitutions: const {
        'ribeye steak': 'Thick-cut New York strip or bone-in porterhouse (at least 1.5 inches thick).',
        'unsalted butter': 'Ghee or cultured salted butter (reduce kosher salt slightly).',
        'rosemary and thyme': 'Fresh tarragon, oregano, or savory.',
      },
    ),

    // --- SUBSEQUENT RECIPES: verified = false ---
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
      baseServings: 4,
      difficulty: 'Easy',
      imageUrl: 'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&w=800&q=80',
      isTrending: true,
      verified: false,
      source: 'curated',
      normalizedName: 'golden fluffy buttermilk pancake',
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
      id: 'steamed-dimsum-dumplings',
      slug: 'steamed-dimsum-dumplings',
      title: 'Steamed Pork & Shrimp Dumplings',
      description: 'Delicate Cantonese dim sum dumplings steamed in bamboo baskets with ginger scallion sauce.',
      category: 'snack',
      cuisine: 'Asian',
      prepTimeMinutes: 25,
      cookTimeMinutes: 15,
      servings: 4,
      baseServings: 4,
      difficulty: 'Medium',
      imageUrl: 'https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?auto=format&fit=crop&w=800&q=80',
      isTrending: true,
      verified: false,
      source: 'curated',
      normalizedName: 'steamed pork shrimp dumpling',
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
      baseServings: 4,
      difficulty: 'Easy',
      imageUrl: 'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?auto=format&fit=crop&w=800&q=80',
      isTrending: true,
      verified: false,
      source: 'curated',
      normalizedName: 'smoky flamegrilled bbq chicken',
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
      id: 'classic-carbonara',
      slug: 'classic-carbonara',
      title: 'Authentic Roman Carbonara',
      description: 'Silky pasta with crispy guanciale, pecorino romano, egg yolks, and coarse black pepper.',
      category: 'dinner',
      cuisine: 'Italian',
      prepTimeMinutes: 10,
      cookTimeMinutes: 15,
      servings: 2,
      baseServings: 2,
      difficulty: 'Medium',
      imageUrl: 'https://images.unsplash.com/photo-1612874742237-6526221588e3?auto=format&fit=crop&w=800&q=80',
      isTrending: false,
      verified: false,
      source: 'curated',
      normalizedName: 'authentic roman carbonara',
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
      baseServings: 1,
      difficulty: 'Easy',
      imageUrl: 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?auto=format&fit=crop&w=800&q=80',
      isTrending: false,
      verified: false,
      source: 'curated',
      normalizedName: 'mango pineapple energy smoothie',
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
