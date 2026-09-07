import 'package:flutter/material.dart';
import '../models/dish.dart';
import '../services/supabase_service.dart';

class ExploreScreen extends StatefulWidget {
  final Function(Dish dish)? onSelectRecipeForCooking;

  const ExploreScreen({super.key, this.onSelectRecipeForCooking});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<Dish> _dishes = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';

  final List<String> _filters = [
    'All',
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snack',
    'Smoothies',
    'Dessert',
  ];

  @override
  void initState() {
    super.initState();
    _loadDishes();
  }

  Future<void> _loadDishes() async {
    setState(() => _isLoading = true);
    final all = await SupabaseService.instance.fetchDishes();
    if (mounted) {
      setState(() {
        _dishes = all;
        _isLoading = false;
      });
    }
  }

  List<Dish> get _filteredDishes {
    if (_selectedCategory == 'All') return _dishes;
    return _dishes
        .where((d) => d.category.toLowerCase() == _selectedCategory.toLowerCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F12) : const Color(0xFFF9FAF7),
      appBar: AppBar(
        title: Text(
          'Explore Dishes',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.4,
            color: isDark ? Colors.white : const Color(0xFF143826),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Pills
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              itemBuilder: (context, idx) {
                final cat = _filters[idx];
                final isSelected = _selectedCategory == cat;

                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826))
                          : (isDark ? const Color(0xFF161A24) : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? (isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826))
                            : (isDark ? const Color(0xFF263042) : const Color(0xFFECEFE8)),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: (isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826))
                                    .withValues(alpha: isDark ? 0.3 : 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? (isDark ? const Color(0xFF143826) : Colors.white)
                              : (isDark ? Colors.white70 : const Color(0xFF4A5568)),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Dishes Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.76,
                    ),
                    itemCount: _filteredDishes.length,
                    itemBuilder: (context, idx) {
                      final dish = _filteredDishes[idx];

                      return GestureDetector(
                        onTap: () => widget.onSelectRecipeForCooking?.call(dish),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161A24) : Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isDark ? const Color(0xFF263042) : const Color(0xFFECEFE8),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius:
                                    const BorderRadius.vertical(top: Radius.circular(22)),
                                child: Image.network(
                                  dish.imageUrl,
                                  height: 125,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dish.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF143826),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${dish.cuisine} • ${dish.totalTimeMinutes}m',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
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
    );
  }
}
