import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/dish.dart';
import '../services/supabase_service.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDishes();
  }

  Future<void> _loadDishes() async {
    setState(() => _isLoading = true);
    final dishes = await SupabaseService.instance.fetchDishes();
    final recentAi = await SupabaseService.instance.fetchRecentlyViewedAIDishes();
    if (mounted) {
      setState(() {
        _dishes = dishes;
        _recentAiDishes = recentAi;
        _isLoading = false;
      });
    }
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
                    // User Avatar Circle
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        image: const DecorationImage(
                          image: NetworkImage(
                            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
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

              // 3. SEARCH BAR: Pill-shaped
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161A24) : Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: isDark ? const Color(0xFF263042) : const Color(0xFFECEFE8),
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
                        color: isDark ? Colors.white38 : const Color(0xFF9E9E9E),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Search here',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white38 : const Color(0xFF9E9E9E),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

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

              const SizedBox(height: 22),

              // 4. CATEGORIES GRID: 2 rows of 4 cards matching the reference image
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.88,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isMore = cat['isMore'] as bool;
                    final isSelected = _selectedCategory == cat['id'];

                    // Mint Lime accent for "More" button in unified 2-color brand theme
                    final cardBg = isMore
                        ? const Color(0xFFD2E68B)
                        : (isDark ? const Color(0xFF161A24) : Colors.white);

                    final textColor = isMore
                        ? const Color(0xFF143826)
                        : (isDark ? Colors.white70 : const Color(0xFF4A5568));

                    final iconColor = isMore
                        ? const Color(0xFF143826)
                        : (cat['iconColor'] as Color);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory =
                              _selectedCategory == cat['id'] ? 'all' : cat['id'] as String;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected || isMore
                                ? const Color(0xFFD2E68B)
                                : (isDark ? const Color(0xFF263042) : const Color(0xFFECEFE8)),
                            width: isSelected || isMore ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isMore
                                  ? const Color(0xFFD2E68B).withValues(alpha: 0.3)
                                  : Colors.black.withValues(alpha: 0.02),
                              blurRadius: isMore ? 8 : 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              cat['icon'] as IconData,
                              size: 26,
                              color: iconColor,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              cat['label'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isMore ? FontWeight.w800 : FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 28),

              // 5. SECTION: "Recently Viewed in AI" (Replaces Trending Recipes Carousel)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recently Viewed',
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
                      'Recipes you recently explored with your voice sous-chef',
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
}
