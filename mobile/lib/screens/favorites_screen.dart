import 'package:flutter/material.dart';
import '../models/dish.dart';
import '../services/supabase_service.dart';

class FavoritesScreen extends StatefulWidget {
  final Function(Dish dish)? onSelectRecipeForCooking;

  const FavoritesScreen({super.key, this.onSelectRecipeForCooking});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Dish> _favoriteDishes = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedCategory = 'all';

  final List<Map<String, String>> _categories = [
    {'id': 'all', 'label': 'All'},
    {'id': 'breakfast', 'label': 'Breakfast'},
    {'id': 'lunch', 'label': 'Lunch'},
    {'id': 'dinner', 'label': 'Dinner'},
    {'id': 'snack', 'label': 'Snack'},
    {'id': 'dessert', 'label': 'Dessert'},
  ];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final all = await SupabaseService.instance.fetchDishes();
      final favIds = SupabaseService.instance.favoriteDishIds;
      
      if (mounted) {
        setState(() {
          _favoriteDishes = all
              .where((d) => favIds.contains(d.id))
              .where((d) => _selectedCategory == 'all' || d.category == _selectedCategory)
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[FavoritesScreen] Error loading favorites: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Couldn\'t load your favorites. Please try again.';
          _isLoading = false;
        });
      }
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
                'Recipes You Liked',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : const Color(0xFF143826),
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
                      label: Text(category['label']!),
                      onSelected: (_) {
                        setState(() => _selectedCategory = category['id']!);
                        _loadFavorites();
                      },
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
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
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
                          onPressed: _loadFavorites,
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
                )
              : _favoriteDishes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border_rounded,
                        size: 64,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No recipes liked yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF143826),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap the heart icon on any dish to save it here',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white38 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  itemCount: _favoriteDishes.length,
                  itemBuilder: (context, idx) {
                    final dish = _favoriteDishes[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161A24) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0xFF263042) : const Color(0xFFECEFE8),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            dish.imageUrl,
                            width: 68,
                            height: 68,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                dish.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF143826),
                                ),
                              ),
                            ),
                            // Verified/AI Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: dish.verified
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: dish.verified
                                      ? const Color(0xFF10B981)
                                      : Colors.amber.shade700,
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    dish.verified ? Icons.verified_rounded : Icons.auto_awesome_rounded,
                                    size: 10,
                                    color: dish.verified ? const Color(0xFF10B981) : Colors.amber.shade700,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    dish.verified ? 'Verified' : 'AI',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: dish.verified ? const Color(0xFF10B981) : Colors.amber.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${dish.cuisine} • ${dish.totalTimeMinutes} min',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.favorite_rounded, color: Color(0xFFEF4444)),
                          onPressed: () {
                            setState(() {
                              SupabaseService.instance.toggleFavorite(dish.id);
                              _loadFavorites();
                            });
                          },
                        ),
                        onTap: () => widget.onSelectRecipeForCooking?.call(dish),
                      ),
                    ),
                    );
                  },
                ),
            ),
          ],
        ),
      ),
    );
  }
}
