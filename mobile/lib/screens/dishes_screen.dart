import 'package:flutter/material.dart';
import '../models/dish.dart';
import '../services/supabase_service.dart';

class DishesScreen extends StatefulWidget {
  final Function(Dish) onSelectRecipeForCooking;

  const DishesScreen({
    super.key,
    required this.onSelectRecipeForCooking,
  });

  @override
  State<DishesScreen> createState() => _DishesScreenState();
}

class _DishesScreenState extends State<DishesScreen> {
  String _selectedCategory = 'all';
  List<Dish> _dishes = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Same 8 categories as Home screen
  final List<Map<String, dynamic>> _categories = [
    {'id': 'all', 'label': 'All', 'icon': Icons.grid_view_rounded},
    {'id': 'breakfast', 'label': 'Breakfast', 'icon': Icons.soup_kitchen_rounded},
    {'id': 'lunch', 'label': 'Lunch', 'icon': Icons.lunch_dining_rounded},
    {'id': 'dinner', 'label': 'Dinner', 'icon': Icons.dinner_dining_rounded},
    {'id': 'snack', 'label': 'Snack', 'icon': Icons.kebab_dining_rounded},
    {'id': 'cuisine', 'label': 'Cuisine', 'icon': Icons.ramen_dining_rounded},
    {'id': 'smoothies', 'label': 'Smoothies', 'icon': Icons.local_cafe_rounded},
    {'id': 'dessert', 'label': 'Dessert', 'icon': Icons.cake_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadDishes();
  }

  Future<void> _loadDishes() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Server-side filtering by category
      final dishes = _selectedCategory == 'all'
          ? await SupabaseService.instance.fetchDishes()
          : await SupabaseService.instance.fetchDishes(category: _selectedCategory);

      if (mounted) {
        setState(() {
          _dishes = dishes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Couldn\'t load dishes. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _onCategorySelected(String categoryId) {
    if (_selectedCategory != categoryId) {
      setState(() => _selectedCategory = categoryId);
      _loadDishes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F12) : const Color(0xFFF9FAF7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Dishes',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF143826),
                  letterSpacing: -0.6,
                ),
              ),
            ),

            // Category Filter Chips
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category['id'];

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: FilterChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            category['icon'] as IconData,
                            size: 16,
                            color: isSelected
                                ? const Color(0xFF143826)
                                : (isDark ? Colors.white70 : Colors.black54),
                          ),
                          const SizedBox(width: 6),
                          Text(category['label'] as String),
                        ],
                      ),
                      onSelected: (_) => _onCategorySelected(category['id'] as String),
                      backgroundColor: isDark ? const Color(0xFF1B1F27) : Colors.white,
                      selectedColor: const Color(0xFFD2E68B),
                      labelStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF143826)
                            : (isDark ? Colors.white70 : Colors.black54),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFFD2E68B)
                              : (isDark ? const Color(0xFF2E3544) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Content Area
            Expanded(
              child: _isLoading
                  ? _buildLoadingState(isDark)
                  : _errorMessage != null
                      ? _buildErrorState(isDark)
                      : _dishes.isEmpty
                          ? _buildEmptyState(isDark)
                          : _buildDishGrid(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading dishes...',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: isDark ? Colors.red.shade300 : Colors.red.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDishes,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD2E68B),
                foregroundColor: const Color(0xFF143826),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu_rounded,
              size: 64,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedCategory == 'all'
                  ? 'No dishes yet'
                  : 'No ${_categories.firstWhere((c) => c['id'] == _selectedCategory)['label']} dishes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first dish with AI\nor explore other categories',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDishGrid(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _dishes.length,
      itemBuilder: (context, index) {
        final dish = _dishes[index];
        final isFav = SupabaseService.instance.isFavorite(dish.id);
        final hasCookedBefore = SupabaseService.instance.hasCookedBefore(dish.id);

        return GestureDetector(
          onTap: () => widget.onSelectRecipeForCooking(dish),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isDark ? const Color(0xFF1B1F27) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image with badges
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Image.network(
                        dish.imageUrl,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 140,
                          color: Colors.grey[300],
                          child: const Icon(Icons.restaurant, size: 32),
                        ),
                      ),
                    ),

                    // Favorite Button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            SupabaseService.instance.toggleFavorite(dish.id);
                          });
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Icon(
                            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isFav ? const Color(0xFFEF4444) : Colors.black45,
                            size: 16,
                          ),
                        ),
                      ),
                    ),

                    // Verified/AI Badge
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: dish.verified
                              ? const Color(0xFF10B981).withValues(alpha: 0.9)
                              : Colors.amber.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              dish.verified ? Icons.verified_rounded : Icons.auto_awesome_rounded,
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              dish.verified ? 'Verified' : 'AI',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Cooked Before Badge
                    if (hasCookedBefore)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF143826).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 10,
                                color: Color(0xFFD2E68B),
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Cooked',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD2E68B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                // Dish Info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dish.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF143826),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${dish.totalTimeMinutes} min',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
