import 'package:flutter/material.dart';
import '../models/dish.dart';
import '../services/supabase_service.dart';
import 'dish_history_detail_screen.dart';

class RecentlyViewedScreen extends StatefulWidget {
  final Function(Dish dish)? onSelectRecipeForCooking;

  const RecentlyViewedScreen({
    super.key,
    this.onSelectRecipeForCooking,
  });

  @override
  State<RecentlyViewedScreen> createState() => _RecentlyViewedScreenState();
}

class _RecentlyViewedScreenState extends State<RecentlyViewedScreen> {
  List<Dish> _dishes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentDishes();
    SupabaseService.instance.cookHistoryNotifier.addListener(_loadRecentDishes);
  }

  @override
  void dispose() {
    SupabaseService.instance.cookHistoryNotifier.removeListener(_loadRecentDishes);
    super.dispose();
  }

  Future<void> _loadRecentDishes() async {
    setState(() => _isLoading = true);
    final items = await SupabaseService.instance.fetchRecentlyViewedAIDishes();
    if (mounted) {
      setState(() {
        _dishes = items;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F12) : const Color(0xFFF9FAF7),
      appBar: AppBar(
        title: Text(
          'History',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.4,
            color: isDark ? Colors.white : const Color(0xFF143826),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh history',
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white70 : const Color(0xFF143826),
            ),
            onPressed: _loadRecentDishes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFD2E68B),
              ),
            )
          : _dishes.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: _dishes.length,
                  itemBuilder: (context, index) {
                    final dish = _dishes[index];
                    return _buildDishCard(dish, isDark);
                  },
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
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF1E232B) : const Color(0xFFECEFE8),
              ),
              child: Icon(
                Icons.history_toggle_off_rounded,
                size: 36,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Cooking History Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF143826),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start cooking any recipe or generate one with AI to track your history here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDishCard(Dish dish, bool isDark) {
    final hasCooked = SupabaseService.instance.hasCookedBefore(dish.id) ||
        SupabaseService.instance.hasCookedBefore(dish.slug);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DishHistoryDetailScreen(
                  dish: dish,
                  onSelectRecipeForCooking: widget.onSelectRecipeForCooking,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dish Thumbnail Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    dish.imageUrl,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 88,
                      height: 88,
                      color: isDark ? const Color(0xFF263042) : const Color(0xFFE5E7EB),
                      child: Icon(
                        Icons.restaurant_rounded,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Dish Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges row
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Trust badge (only if verified)
                          if (dish.verified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF10B981),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 11,
                                    color: const Color(0xFF10B981),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Verified',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Cooked before badge
                          if (hasCooked)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF263042)
                                    : const Color(0xFFE9EDDF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Cooked before',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Dish Title
                      Text(
                        dish.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF143826),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Meta details: category, time, steps
                      Row(
                        children: [
                          Text(
                            dish.category.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            ' • ',
                            style: TextStyle(
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                          ),
                          Icon(
                            Icons.timer_outlined,
                            size: 13,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${dish.totalTimeMinutes}m',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            ' • ',
                            style: TextStyle(
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                          ),
                          Text(
                            '${dish.steps.length} steps',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Chevron icon
                Padding(
                  padding: const EdgeInsets.only(top: 30, left: 4),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
