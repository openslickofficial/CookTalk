import 'package:flutter/material.dart';
import '../models/dish.dart';
import '../services/supabase_service.dart';

class DishHistoryDetailScreen extends StatefulWidget {
  final Dish dish;
  final Function(Dish dish)? onSelectRecipeForCooking;

  const DishHistoryDetailScreen({
    super.key,
    required this.dish,
    this.onSelectRecipeForCooking,
  });

  @override
  State<DishHistoryDetailScreen> createState() => _DishHistoryDetailScreenState();
}

class _DishHistoryDetailScreenState extends State<DishHistoryDetailScreen> {
  late bool _isWishlisted;

  @override
  void initState() {
    super.initState();
    _isWishlisted = SupabaseService.instance.isFavorite(widget.dish.id) ||
        SupabaseService.instance.isFavorite(widget.dish.slug);
  }

  void _toggleWishlist() {
    setState(() {
      _isWishlisted = !_isWishlisted;
    });
    SupabaseService.instance.toggleFavorite(widget.dish.id);
    if (widget.dish.slug != widget.dish.id) {
      SupabaseService.instance.toggleFavorite(widget.dish.slug);
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: const Color(0xFF143826),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isWishlisted
                    ? 'Added "${widget.dish.title}" to your Wishlist!'
                    : 'Removed "${widget.dish.title}" from Wishlist',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF143826),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD2E68B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatLastCooked(DateTime? dt) {
    if (dt == null) return 'Not recorded';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return m <= 1 ? 'Just now' : '$m mins ago';
    } else if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h hour${h == 1 ? '' : 's'} ago';
    } else if (diff.inDays < 7) {
      final d = diff.inDays;
      return '$d day${d == 1 ? '' : 's'} ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dish = widget.dish;
    final totalMinutes = dish.prepTimeMinutes + dish.cookTimeMinutes;
    final lastCookedDate = SupabaseService.instance.getLastCookedAt(dish.id) ??
        SupabaseService.instance.getLastCookedAt(dish.slug);
    final hasCooked = SupabaseService.instance.hasCookedBefore(dish.id) ||
        SupabaseService.instance.hasCookedBefore(dish.slug);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F12) : const Color(0xFFF9FAF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E232B) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? const Color(0xFF263042) : const Color(0xFFECEFE8),
              ),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: isDark ? Colors.white : const Color(0xFF143826),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Dish History',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.4,
            color: isDark ? Colors.white : const Color(0xFF143826),
          ),
        ),
        actions: [
          IconButton(
            tooltip: _isWishlisted ? 'Remove from Wishlist' : 'Add to Wishlist',
            icon: Icon(
              _isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isWishlisted
                  ? const Color(0xFFE53E3E)
                  : (isDark ? Colors.white70 : const Color(0xFF143826)),
            ),
            onPressed: _toggleWishlist,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HERO IMAGE WITH TAGS
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(
                    dish.imageUrl,
                    width: double.infinity,
                    height: 230,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: double.infinity,
                      height: 230,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E232B) : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        Icons.restaurant_rounded,
                        size: 64,
                        color: isDark ? Colors.white24 : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
                // Top Tag Badges
                Positioned(
                  top: 14,
                  left: 14,
                  child: Row(
                    children: [
                      if (dish.verified) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, size: 13, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (hasCooked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E232B) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFD2E68B),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Text(
                            'Cooked before',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Bottom Difficulty & Cuisine Pills
                Positioned(
                  bottom: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${dish.cuisine} • ${dish.difficulty}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 2. DISH TITLE & DESCRIPTION
            Text(
              dish.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : const Color(0xFF143826),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              dish.description,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: isDark ? Colors.white70 : const Color(0xFF4A5568),
              ),
            ),

            const SizedBox(height: 18),

            // 3. TIME TAKEN & COOKING METRICS GRID
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161A24) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF263042) : const Color(0xFFECEFE8),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildMetricTile(
                        icon: Icons.timer_rounded,
                        label: 'Total Time',
                        value: '$totalMinutes mins',
                        isDark: isDark,
                      ),
                      _buildDivider(isDark),
                      _buildMetricTile(
                        icon: Icons.outdoor_grill_rounded,
                        label: 'Cook Time',
                        value: '${dish.cookTimeMinutes} mins',
                        isDark: isDark,
                      ),
                      _buildDivider(isDark),
                      _buildMetricTile(
                        icon: Icons.kitchen_rounded,
                        label: 'Prep Time',
                        value: '${dish.prepTimeMinutes} mins',
                        isDark: isDark,
                      ),
                      _buildDivider(isDark),
                      _buildMetricTile(
                        icon: Icons.format_list_numbered_rounded,
                        label: 'Total Steps',
                        value: '${dish.steps.isNotEmpty ? dish.steps.length : 5}',
                        isDark: isDark,
                      ),
                    ],
                  ),
                  if (hasCooked) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Colors.white12),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 16,
                          color: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Last cooked: ${_formatLastCooked(lastCookedDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 4. INTERACTIVE "ADD TO WISHLIST" BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _toggleWishlist,
                icon: Icon(
                  _isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 20,
                  color: _isWishlisted ? Colors.white : const Color(0xFF143826),
                ),
                label: Text(
                  _isWishlisted ? 'In Wishlist • Tap to Remove' : 'Add to Wishlist',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: _isWishlisted ? Colors.white : const Color(0xFF143826),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isWishlisted
                      ? const Color(0xFFE53E3E)
                      : const Color(0xFFD2E68B),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 5. INGREDIENTS LIST
            Text(
              'Ingredients (${dish.ingredients.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF143826),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161A24) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF263042) : const Color(0xFFECEFE8),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dish.ingredients.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF263042) : const Color(0xFFECEFE8),
                ),
                itemBuilder: (context, idx) {
                  final ing = dish.ingredients[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD2E68B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ing.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF143826),
                            ),
                          ),
                        ),
                        Text(
                          '${ing.quantity} ${ing.unit}'.trim(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFD2E68B) : const Color(0xFF7D9344),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // 6. TOTAL STEPS BREAKDOWN
            Text(
              'Cooking Steps (${dish.steps.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF143826),
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dish.steps.length,
              itemBuilder: (context, idx) {
                final s = dish.steps[idx];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161A24) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? const Color(0xFF263042) : const Color(0xFFECEFE8),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD2E68B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${s.step}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF143826),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          s.instruction,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : const Color(0xFF143826),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161A24) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF263042) : const Color(0xFFECEFE8),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onSelectRecipeForCooking?.call(dish);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
            foregroundColor: isDark ? const Color(0xFF143826) : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mic_rounded,
                size: 20,
                color: isDark ? const Color(0xFF143826) : const Color(0xFFD2E68B),
              ),
              const SizedBox(width: 10),
              Text(
                'Start Cooking Session',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: isDark ? const Color(0xFF143826) : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF143826),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 32,
      color: isDark ? const Color(0xFF263042) : const Color(0xFFECEFE8),
    );
  }
}
