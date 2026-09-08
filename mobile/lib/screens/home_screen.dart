import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/dish.dart';
import '../services/supabase_service.dart';
import '../widgets/user_avatar.dart';

class HomeScreen extends StatefulWidget {
  final Function(Dish dish)? onSelectRecipeForCooking;

  const HomeScreen({
    super.key,
    this.onSelectRecipeForCooking,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'all';
  List<Dish> _dishes = [];
  List<Dish> _recentAiDishes = [];
  List<String> _staticDishNames = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDishes();
    SupabaseService.instance.cookHistoryNotifier.addListener(_loadDishes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    SupabaseService.instance.cookHistoryNotifier.removeListener(_loadDishes);
    super.dispose();
  }

  Future<void> _loadDishes() async {
    setState(() => _isLoading = true);
    final dishes = await SupabaseService.instance.fetchDishes();
    final recentAi = await SupabaseService.instance.fetchRecentlyViewedAIDishes();
    final staticNames = await SupabaseService.instance.loadStaticDishNames();
    if (mounted) {
      setState(() {
        _dishes = dishes;
        _recentAiDishes = recentAi;
        _staticDishNames = staticNames;
        _isLoading = false;
      });
    }
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> v0 = List<int>.generate(b.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        int cost = (a[i] == b[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((curr, next) => curr < next ? curr : next);
      }
      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[b.length];
  }

  bool _isFuzzyMatch(String query, String target) {
    final q = Dish.normalize(query);
    final t = Dish.normalize(target);
    if (q.isEmpty || t.isEmpty) return false;

    // Direct whole-string match or substring match (if query is at least 3 chars)
    if (q.length >= 3 && t.contains(q)) return true;
    if (t.length >= 3 && q.contains(t)) return true;

    final allTargetWords = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    // For short queries (e.g. 2 chars), check prefix matching on target words
    if (q.length < 3) {
      return allTargetWords.any((tw) => tw.startsWith(q));
    }

    final qWords = q.split(RegExp(r'\s+')).where((w) => w.length >= 3).toList();
    final tWords = allTargetWords.where((w) => w.length >= 3).toList();
    if (qWords.isEmpty || tWords.isEmpty) return false;

    for (final qw in qWords) {
      for (final tw in tWords) {
        // Exact word match
        if (qw == tw) return true;

        // Prefix match: e.g. qw 'panc' starts tw 'pancake'
        if (qw.length >= 3 && tw.startsWith(qw)) return true;
        if (tw.length >= 4 && qw.startsWith(tw)) return true;

        // Typo tolerance via Levenshtein distance
        final lenDiff = (qw.length - tw.length).abs();
        if (lenDiff > 2) continue; // length difference too large for single-word typo

        final minLen = math.min(qw.length, tw.length);
        if (minLen < 4) continue; // no fuzzy matching for 3-letter words

        final maxDist = minLen <= 5 ? 1 : 2;
        if (_levenshtein(qw, tw) <= maxDist) return true;
      }
    }
    return false;
  }

  List<Dish> get _matchedExistingDishes {
    final q = _searchQuery.trim();
    if (q.isEmpty) return [];
    return _dishes
        .where((d) =>
            _isFuzzyMatch(q, d.title) ||
            _isFuzzyMatch(q, d.slug) ||
            _isFuzzyMatch(q, d.normalizedName))
        .toList();
  }

  List<String> get _matchedStaticNames {
    final q = _searchQuery.trim();
    if (q.isEmpty) return [];
    final existingNorms = _dishes.map((d) => d.normalizedName).toSet();
    return _staticDishNames
        .where((name) {
          final norm = Dish.normalize(name);
          if (existingNorms.contains(norm)) return false;
          return _isFuzzyMatch(q, name);
        })
        .take(6)
        .toList();
  }

  // Exact 8 categories matching the reference design image
  final List<Map<String, dynamic>> _categories = [
    {
      'id': 'breakfast',
      'label': 'Breakfast',
      'icon': Icons.soup_kitchen_rounded,
      'iconColor': Color(0xFF7D9344),
      'isMore': false,
    },
    {
      'id': 'lunch',
      'label': 'Lunch',
      'icon': Icons.lunch_dining_rounded,
      'iconColor': Color(0xFFE5A024),
      'isMore': false,
    },
    {
      'id': 'dinner',
      'label': 'Dinner',
      'icon': Icons.dinner_dining_rounded,
      'iconColor': Color(0xFF7D9344),
      'isMore': false,
    },
    {
      'id': 'snack',
      'label': 'Snack',
      'icon': Icons.kebab_dining_rounded,
      'iconColor': Color(0xFFE5A024),
      'isMore': false,
    },
    {
      'id': 'cuisine',
      'label': 'Cuisine',
      'icon': Icons.ramen_dining_rounded,
      'iconColor': Color(0xFFE5A024),
      'isMore': false,
    },
    {
      'id': 'smoothies',
      'label': 'Smoothies',
      'icon': Icons.local_cafe_rounded,
      'iconColor': Color(0xFF7D9344),
      'isMore': false,
    },
    {
      'id': 'dessert',
      'label': 'Dessert',
      'icon': Icons.cake_rounded,
      'iconColor': Color(0xFFE5A024),
      'isMore': false,
    },
    {
      'id': 'more',
      'label': 'More',
      'icon': Icons.grid_view_rounded,
      'iconColor': Color(0xFF143826),
      'isMore': true, // highlighted in mint lime
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = SupabaseService.instance.currentUser;
    final userName = user?.fullName ?? 'Samantha';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F12) : const Color(0xFFF9FAF7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP BAR: Avatar, Name & Notification Bell
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    // User Avatar with DiceBear SVG support
                    UserAvatar(
                      avatarUrl: user?.avatarUrl,
                      username: userName,
                      size: 44,
                    ),
                    const SizedBox(width: 12),

                    // User Name
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF2C3E2D),
                      ),
                    ),

                    const Spacer(),

                    // Notification Bell in rounded container
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1F29) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF2B3545) : const Color(0xFFECEFE8),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            color: isDark ? Colors.white70 : const Color(0xFF333333),
                            size: 22,
                          ),
                          Positioned(
                            top: 11,
                            right: 12,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFFD2E68B),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. HERO HEADLINE: "What's cooking today?"
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: Text(
                  "What's cooking today?",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF143826),
                    letterSpacing: -0.6,
                  ),
                ),
              ),

              // 3. SEARCH BAR: Search-as-you-type with zero network calls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161A24) : Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: _searchFocusNode.hasFocus
                          ? const Color(0xFFD2E68B)
                          : (isDark ? const Color(0xFF263042) : const Color(0xFFECEFE8)),
                      width: _searchFocusNode.hasFocus ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: isDark ? Colors.white54 : const Color(0xFF143826),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? Colors.white : const Color(0xFF143826),
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search dishes (e.g. paneer, ramen)...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white38 : const Color(0xFF9E9E9E),
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          child: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              if (_searchQuery.trim().isNotEmpty) ...[
                _buildSearchResults(isDark),
              ] else ...[
                const SizedBox(height: 18),

              // ==================================================================
              // BANNER CTA: Cooking & Prep Assistant
              // ==================================================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161A24) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? const Color(0xFF263042) : const Color(0xFFECEFE8),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Subtle decorative kitchen accent icon in corner
                      Positioned(
                        top: -12,
                        right: -12,
                        child: Icon(
                          Icons.microwave_rounded,
                          size: 96,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : const Color(0xFF143826).withValues(alpha: 0.03),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Pill: [🎙️ VOICE ASSISTANT]
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFFD2E68B).withValues(alpha: 0.15)
                                    : const Color(0xFF143826).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFFD2E68B).withValues(alpha: 0.4)
                                      : const Color(0xFF143826).withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.mic_rounded,
                                    size: 13,
                                    color: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'VOICE ASSISTANT',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Main Headline
                            Text(
                              'Hands Messy in the Kitchen?',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                                color: isDark ? Colors.white : const Color(0xFF143826),
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Subtitle description
                            Text(
                              'Talk to your AI sous-chef for step-by-step guidance, instant timers, and hands-free ingredient swaps.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                fontWeight: FontWeight.w400,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Action Button: [ Start Cooking Assistant 🎙️ ]
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () {
                                  widget.onSelectRecipeForCooking?.call(
                                    _dishes.isNotEmpty
                                        ? _dishes.first
                                        : const Dish(
                                            id: 'pancakes',
                                            slug: 'pancakes',
                                            title: 'Golden Diner-Style Fluffy Buttermilk Pancakes',
                                            description: 'Classic diner-style pancakes with crispy edges and soft centers.',
                                            cuisine: 'American',
                                            category: 'Breakfast',
                                            difficulty: 'Easy',
                                            prepTimeMinutes: 10,
                                            cookTimeMinutes: 15,
                                            servings: 4,
                                            imageUrl: 'https://images.unsplash.com/photo-1528207776546-365bb710ee93?auto=format&fit=crop&w=800&q=80',
                                            ingredients: [],
                                            steps: [],
                                          ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? const Color(0xFFD2E68B)
                                      : const Color(0xFF143826),
                                  foregroundColor: isDark
                                      ? const Color(0xFF143826)
                                      : Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Start Cooking Assistant',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                        color: isDark
                                            ? const Color(0xFF143826)
                                            : Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.mic_rounded,
                                      size: 18,
                                      color: isDark
                                          ? const Color(0xFF143826)
                                          : const Color(0xFFD2E68B),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 4. SECTION: "Cooking History"
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cooking History',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF143826),
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          'See all',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recipes you cooked or explored with your voice sous-chef',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 6. RECENTLY VIEWED IN AI HORIZONTAL CAROUSEL
              SizedBox(
                height: 320,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _recentAiDishes.isNotEmpty ? _recentAiDishes.length : _dishes.length,
                        itemBuilder: (context, index) {
                          final dish = _recentAiDishes.isNotEmpty ? _recentAiDishes[index] : _dishes[index];
                          final isFav = SupabaseService.instance.isFavorite(dish.id);

                          return Container(
                            width: 230,
                            margin: const EdgeInsets.only(right: 16),
                            child: GestureDetector(
                              onTap: () {
                                SupabaseService.instance.recordDishViewedInAI(dish.id);
                                _showRecipePreview(context, dish);
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Large Rounded Image with Badges
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(26),
                                        child: Image.network(
                                          dish.imageUrl,
                                          width: 230,
                                          height: 220,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            width: 230,
                                            height: 220,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.restaurant, size: 40),
                                          ),
                                        ),
                                      ),

                                      // Floating Heart Favorite Button
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              SupabaseService.instance.toggleFavorite(dish.id);
                                            });
                                          },
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.15),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Icon(
                                                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                                color: isFav ? const Color(0xFFEF4444) : Colors.black45,
                                                size: 19,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Prep Time Badge
                                      Positioned(
                                        bottom: 12,
                                        left: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.65),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.schedule_rounded, color: Colors.white, size: 12),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${dish.totalTimeMinutes} min',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Voice Cook Quick Pill
                                      Positioned(
                                        bottom: 12,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFFD2E68B)
                                                : const Color(0xFF143826).withValues(alpha: 0.92),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.mic_rounded,
                                                color: isDark ? const Color(0xFF143826) : const Color(0xFFD2E68B),
                                                size: 12,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                'Cook',
                                                style: TextStyle(
                                                  color: isDark ? const Color(0xFF143826) : Colors.white,
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  // Trust badge + Cooked before
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      if (SupabaseService.instance.hasCookedBefore(dish.id) ||
                                          SupabaseService.instance.hasCookedBefore(dish.slug))
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF263042) : const Color(0xFFE9EDDF),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            'Cooked before',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),

                                  // Dish Title
                                  Text(
                                    dish.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF143826),
                                    ),
                                  ),
                                  const SizedBox(height: 3),

                                  // Cuisine & Difficulty subtitle
                                  Text(
                                    '${dish.cuisine} • ${dish.difficulty} • AI Voice Ready',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

  void _showRecipePreview(BuildContext context, Dish dish) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121620) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              // Pull Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        dish.imageUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      dish.title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF143826),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (dish.verified)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF10B981),
                                width: 0.8,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  size: 12,
                                  color: Color(0xFF10B981),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Verified',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (SupabaseService.instance.hasCookedBefore(dish.id) ||
                            SupabaseService.instance.hasCookedBefore(dish.slug)) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF263042) : const Color(0xFFE9EDDF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Cooked before',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      dish.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ingredients Preview
                    Text(
                      'Ingredients (${dish.ingredients.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: dish.ingredients.map((ing) {
                        return Chip(
                          label: Text('${ing.quantity} ${ing.unit} ${ing.name}'),
                          labelStyle: const TextStyle(fontSize: 12),
                          backgroundColor: isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // Launch Voice Assistant Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onSelectRecipeForCooking?.call(dish);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
                      foregroundColor: isDark ? const Color(0xFF143826) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mic_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Start Cooking with AI Voice',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(bool isDark) {
    final existingMatches = _matchedExistingDishes;
    final staticMatches = _matchedStaticNames;
    final query = _searchQuery.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161A24) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF263042) : const Color(0xFFECEFE8),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. EXISTING DISHES SECTION (Matches ranked first)
            if (existingMatches.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(
                  'MATCHING RECIPES (${existingMatches.length})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
                  ),
                ),
              ),
              ...existingMatches.map((dish) {
                final hasCooked = SupabaseService.instance.hasCookedBefore(dish.id) ||
                    SupabaseService.instance.hasCookedBefore(dish.slug);
                return InkWell(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    widget.onSelectRecipeForCooking?.call(dish);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            dish.imageUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 44,
                              height: 44,
                              color: isDark ? const Color(0xFF263042) : const Color(0xFFE5E7EB),
                              child: const Icon(Icons.restaurant, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dish.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF143826),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: dish.verified
                                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: dish.verified
                                        ? const Text(
                                            'Verified',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF10B981),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  if (hasCooked) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF263042) : const Color(0xFFE9EDDF),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Cooked before',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const Divider(height: 1),
            ],

            // 2. STATIC SUGGESTIONS (Ranked second, visually distinct)
            if (staticMatches.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(
                  'SUGGESTED DISHES (TAP TO GENERATE)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ),
              ...staticMatches.map((name) {
                return InkWell(
                  onTap: () => _showConfirmToGenerateSheet(context, name),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF263042) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                            color: isDark ? const Color(0xFFD2E68B) : const Color(0xFF7D9344),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                'New dish • Tap to generate with AI',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text('✨', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                );
              }),
              const Divider(height: 1),
            ],

            // 3. UNLISTED QUERY TILE (Prompt to generate exact query)
            InkWell(
              onTap: () => _showConfirmToGenerateSheet(context, query),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD2E68B).withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: Color(0xFF143826),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : const Color(0xFF143826),
                              ),
                              children: [
                                const TextSpan(text: 'Generate recipe for "'),
                                TextSpan(
                                  text: query,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const TextSpan(text: '"'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'AI-developed recipe with custom steps and timers',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFD2E68B),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmToGenerateSheet(BuildContext context, String dishName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        bool isGenerating = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161A24) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: isDark ? const Color(0xFF263042) : const Color(0xFFECEFE8),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD2E68B).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFD2E68B)),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF143826),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Generate Recipe with AI?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF143826),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dishName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFD2E68B) : const Color(0xFF7D9344),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F2532) : const Color(0xFFF4F7EE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2B3545) : const Color(0xFFDCE4CD),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.restaurant_menu_rounded,
                              size: 20,
                              color: Color(0xFF7D9344),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ready to cook "$dishName"?',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  color: isDark ? Colors.white : const Color(0xFF143826),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Chef CookTalk will craft a tailored recipe with step-by-step guidance, ingredient measurements, and interactive cooking timers.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey.shade300 : const Color(0xFF2C3E2D),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildFeaturePill(Icons.mic_rounded, 'Voice Guided', isDark),
                            _buildFeaturePill(Icons.timer_outlined, 'Smart Timers', isDark),
                            _buildFeaturePill(Icons.swap_horiz_rounded, 'Ingredient Swaps', isDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (isGenerating) ...[
                    Center(
                      child: Column(
                        children: [
                          const CircularProgressIndicator(color: Color(0xFFD2E68B)),
                          const SizedBox(height: 12),
                          Text(
                            'Chef AI is developing your recipe...',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF143826),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white70 : Colors.grey.shade700,
                              side: BorderSide(
                                color: isDark ? const Color(0xFF2B3545) : const Color(0xFFECEFE8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              setSheetState(() {
                                isGenerating = true;
                                errorMessage = null;
                              });
                              try {
                                final host = Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';
                                final generated = await SupabaseService.instance.generateDishViaServer(dishName, host);
                                if (!mounted || !sheetContext.mounted) return;
                                Navigator.of(sheetContext).pop();
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  if (!_dishes.any((d) => d.id == generated.id)) {
                                    _dishes.insert(0, generated);
                                  }
                                });
                                widget.onSelectRecipeForCooking?.call(generated);
                              } catch (e) {
                                setSheetState(() {
                                  isGenerating = false;
                                  errorMessage = 'Generation failed: $e';
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD2E68B),
                              foregroundColor: const Color(0xFF143826),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome_rounded, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Generate Recipe',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFeaturePill(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161A24) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2B3545) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF7D9344)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF2C3E2D),
            ),
          ),
        ],
      ),
    );
  }
}
