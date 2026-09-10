import 'package:flutter/foundation.dart';
import '../models/dish.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';

/// Centralized app state management using ChangeNotifier
/// Handles global state for dishes, favorites, cooking history, and user profile
class AppStateProvider extends ChangeNotifier {
  // Singleton pattern
  static final AppStateProvider _instance = AppStateProvider._internal();
  factory AppStateProvider() => _instance;
  AppStateProvider._internal() {
    _initializeListeners();
  }

  // State variables
  List<Dish> _allDishes = [];
  List<String> _favorites = [];
  List<String> _cookingHistory = [];
  List<String> _recentlyViewed = [];
  UserProfile? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Dish> get allDishes => _allDishes;
  List<String> get favorites => _favorites;
  List<String> get cookingHistory => _cookingHistory;
  List<String> get recentlyViewed => _recentlyViewed;
  UserProfile? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Filtered dishes
  List<Dish> get favoriteDishes {
    return _allDishes.where((dish) => _favorites.contains(dish.id)).toList();
  }

  List<Dish> get cookingHistoryDishes {
    return _allDishes
        .where((dish) => _cookingHistory.contains(dish.id))
        .toList()
      ..sort((a, b) {
        final aIndex = _cookingHistory.indexOf(a.id);
        final bIndex = _cookingHistory.indexOf(b.id);
        return aIndex.compareTo(bIndex);
      });
  }

  List<Dish> get recentlyViewedDishes {
    return _allDishes
        .where((dish) => _recentlyViewed.contains(dish.id))
        .toList()
      ..sort((a, b) {
        final aIndex = _recentlyViewed.indexOf(a.id);
        final bIndex = _recentlyViewed.indexOf(b.id);
        return aIndex.compareTo(bIndex);
      });
  }

  // Initialize listeners to sync with SupabaseService
  void _initializeListeners() {
    // Listen to Supabase service auth changes
    SupabaseService.instance.authStateNotifier.addListener(() {
      _currentUser = SupabaseService.instance.authStateNotifier.value;
      notifyListeners();
    });

    SupabaseService.instance.cookHistoryNotifier.addListener(() {
      _syncCookingHistory();
    });
  }

  // Load all dishes from Supabase
  Future<void> loadDishes() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allDishes = await SupabaseService.instance.fetchDishes();
      _syncFavorites();
      _syncCookingHistory();
      _syncRecentlyViewed();
      _isLoading = false;
      _errorMessage = null;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load dishes: $e';
      debugPrint('[AppStateProvider] Error loading dishes: $e');
    }
    notifyListeners();
  }

  // Sync favorites from SupabaseService
  void _syncFavorites() {
    final user = SupabaseService.instance.currentUser;
    if (user != null) {
      _favorites = List<String>.from(user.favorites);
    } else {
      _favorites = [];
    }
    notifyListeners();
  }

  // Sync cooking history from SupabaseService
  void _syncCookingHistory() {
    // Get all dish IDs that user has cooked
    _cookingHistory = _allDishes
        .where((dish) => SupabaseService.instance.hasCookedBefore(dish.id))
        .map((dish) => dish.id)
        .toList();
    notifyListeners();
  }

  // Sync recently viewed from SupabaseService
  void _syncRecentlyViewed() async {
    // Fetch recently viewed dishes
    try {
      final recentDishes = await SupabaseService.instance.fetchRecentlyViewedAIDishes();
      _recentlyViewed = recentDishes.map((dish) => dish.id).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('[AppStateProvider] Error syncing recently viewed: $e');
    }
  }

  // Toggle favorite status
  Future<void> toggleFavorite(String dishId) async {
    SupabaseService.instance.toggleFavorite(dishId);
    _syncFavorites();
  }

  // Check if dish is favorite
  bool isFavorite(String dishId) {
    return _favorites.contains(dishId);
  }

  // Record cooking history
  Future<void> recordCookHistory(String dishId) async {
    await SupabaseService.instance.recordCookHistory(dishId);
    _syncCookingHistory();
  }

  // Check if dish has been cooked before
  bool hasCookedBefore(String dishId) {
    return _cookingHistory.contains(dishId);
  }

  // Record dish viewed
  Future<void> recordDishViewed(String dishId) async {
    await SupabaseService.instance.recordDishViewedInAI(dishId);
    _syncRecentlyViewed();
  }

  // Refresh all data
  Future<void> refresh() async {
    await loadDishes();
  }

  // Get recommended dishes based on user preferences
  List<Dish> getRecommendedDishes({int limit = 8}) {
    final user = _currentUser;
    final eligibleDishes = _allDishes.where((dish) => dish.verified).toList();

    if (_cookingHistory.isEmpty) {
      // Cold start: filter by favorite cuisines
      if (user != null && user.favoriteCuisines.isNotEmpty) {
        final matchingCuisine = eligibleDishes.where((dish) {
          return user.favoriteCuisines.any((favCuisine) =>
              dish.cuisine.toLowerCase().contains(favCuisine.toLowerCase()) ||
              favCuisine.toLowerCase().contains(dish.cuisine.toLowerCase()));
        }).toList();

        if (matchingCuisine.isNotEmpty) {
          matchingCuisine.sort((a, b) {
            if (a.isTrending && !b.isTrending) return -1;
            if (!a.isTrending && b.isTrending) return 1;
            return 0;
          });
          return matchingCuisine.take(limit).toList();
        }
      }

      // Fallback: trending dishes
      eligibleDishes.sort((a, b) {
        if (a.isTrending && !b.isTrending) return -1;
        if (!a.isTrending && b.isTrending) return 1;
        return 0;
      });
      return eligibleDishes.take(limit).toList();
    }

    // Returning user: rank by cuisine/category overlap
    final cookedDishes = cookingHistoryDishes;
    final cuisineCount = <String, int>{};
    final categoryCount = <String, int>{};

    for (final dish in cookedDishes) {
      cuisineCount[dish.cuisine.toLowerCase()] =
          (cuisineCount[dish.cuisine.toLowerCase()] ?? 0) + 1;
      categoryCount[dish.category.toLowerCase()] =
          (categoryCount[dish.category.toLowerCase()] ?? 0) + 1;
    }

    final scoredDishes = eligibleDishes.map((dish) {
      int score = 0;
      score += (cuisineCount[dish.cuisine.toLowerCase()] ?? 0) * 3;
      score += (categoryCount[dish.category.toLowerCase()] ?? 0) * 2;
      if (dish.isTrending) score += 1;
      return {'dish': dish, 'score': score};
    }).toList();

    scoredDishes.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return scoredDishes
        .take(limit)
        .map((item) => item['dish'] as Dish)
        .toList();
  }

  // Search dishes
  List<Dish> searchDishes(String query, {String category = 'all'}) {
    if (query.isEmpty && category == 'all') {
      return _allDishes;
    }

    return _allDishes.where((dish) {
      final matchesQuery = query.isEmpty ||
          dish.title.toLowerCase().contains(query.toLowerCase()) ||
          dish.description.toLowerCase().contains(query.toLowerCase()) ||
          dish.cuisine.toLowerCase().contains(query.toLowerCase());

      final matchesCategory =
          category == 'all' || dish.category.toLowerCase() == category.toLowerCase();

      return matchesQuery && matchesCategory;
    }).toList();
  }

  // Get dish by ID
  Dish? getDishById(String dishId) {
    try {
      return _allDishes.firstWhere((dish) => dish.id == dishId || dish.slug == dishId);
    } catch (e) {
      return null;
    }
  }
}
