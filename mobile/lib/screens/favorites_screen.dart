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

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final all = await SupabaseService.instance.fetchDishes();
    final favIds = SupabaseService.instance.favoriteDishIds;
    if (mounted) {
      setState(() {
        _favoriteDishes = all.where((d) => favIds.contains(d.id)).toList();
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
          'Recipes You Liked',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
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
                        title: Text(
                          dish.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF143826),
                          ),
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
                    );
                  },
                ),
    );
  }
}
