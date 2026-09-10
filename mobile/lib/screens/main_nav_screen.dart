import 'dart:io';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/dish.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'dishes_screen.dart';
import 'profile_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentTab = 0;

  void _launchCookingSession(Dish? dish) {
    // Production token server on Render.com
    final host = 'https://cooltalk-token-server.onrender.com';
    
    // If no dish is selected, pass null to show proper empty state
    final RecipeItem? targetRecipe = dish != null
        ? RecipeItem(
            id: dish.slug,
            name: dish.title,
            description: dish.description,
            totalSteps: dish.steps.isNotEmpty ? dish.steps.length : 5,
            verified: dish.verified,
            source: dish.source,
            steps: dish.steps.map((s) => {'step': s.step, 'instruction': s.instruction}).toList(),
            ingredients: dish.ingredients.map((i) => {'name': i.name, 'quantity': i.quantity, 'unit': i.unit}).toList(),
          )
        : null;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InSessionScreen(
          serverUrl: host,
          initialRecipe: targetRecipe,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onSelectRecipeForCooking: _launchCookingSession),
      FavoritesScreen(onSelectRecipeForCooking: _launchCookingSession),
      DishesScreen(onSelectRecipeForCooking: _launchCookingSession),
      ProfileScreen(appThemeMode: appThemeMode),
    ];

    return PopScope(
      canPop: _currentTab == 0, // Only allow pop when on home tab
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop && _currentTab != 0) {
          // If not on home tab and trying to exit, navigate to home instead
          setState(() => _currentTab = 0);
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // Current Tab Page
            IndexedStack(
              index: _currentTab,
              children: pages,
            ),

            // Floating Pill Bottom Navigation Bar (Pixel-accurate match with uploaded image)
            Positioned(
              bottom: 24,
              left: 28,
              right: 28,
              child: Container(
                height: 66,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E232B), // Exact dark charcoal pill background
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Tab 0: Home (Active indicator in lime-green pill)
                    _buildNavButton(
                      index: 0,
                      icon: Icons.home_rounded,
                      isActive: _currentTab == 0,
                    ),

                    // Tab 1: Favorites (Heart)
                    _buildNavButton(
                      index: 1,
                      icon: Icons.favorite_border_rounded,
                      activeIcon: Icons.favorite_rounded,
                      isActive: _currentTab == 1,
                    ),

                    // Center Action: Voice Cooking (Mic)
                    GestureDetector(
                      onTap: () => _launchCookingSession(null),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24, width: 1.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.mic_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),

                    // Tab 2: Dishes (Grid icon)
                    _buildNavButton(
                      index: 2,
                      icon: Icons.restaurant_rounded,
                      isActive: _currentTab == 2,
                    ),

                    // Tab 3: Profile (User silhouette)
                    _buildNavButton(
                      index: 3,
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      isActive: _currentTab == 3,
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

  Widget _buildNavButton({
    required int index,
    required IconData icon,
    IconData? activeIcon,
    required bool isActive,
  }) {
    if (isActive) {
      // Active pill indicator in Fresh Mint Lime with Forest Green Icon
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentTab = index),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFD2E68B), // Fresh Mint Lime accent
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD2E68B).withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              activeIcon ?? icon,
              color: const Color(0xFF143826), // Deep Forest Green icon
              size: 24,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _currentTab = index),
      child: Container(
        width: 46,
        height: 46,
        color: Colors.transparent,
        child: Center(
          child: Icon(
            icon,
            color: Colors.white60,
            size: 24,
          ),
        ),
      ),
    );
  }
}
