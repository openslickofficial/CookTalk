import 'package:flutter/material.dart';
import 'auth_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'tag': 'Hands-Free Cooking',
      'tagColor': const Color(0xFF143826),
      'tagBg': const Color(0xFFE8F5E9),
      'title': 'Talk and cook\nat the same time.',
      'subtitle': 'Zero sticky screens. Your voice is your sous-chef for every single instruction.',
      'type': 'stacked_cards',
    },
    {
      'tag': 'Live Voice Timers',
      'tagColor': const Color(0xFF1565C0),
      'tagBg': const Color(0xFFE3F2FD),
      'title': 'Smart timers that\nlisten to you.',
      'subtitle': 'Set multiple resting & searing alarms without ever taking your hands off the knife.',
      'type': 'graphic_badge',
    },
    {
      'tag': 'Tailored Culinary',
      'tagColor': const Color(0xFF6A1B9A),
      'tagBg': const Color(0xFFF3E5F5),
      'title': 'Recipes curated\nto your craving.',
      'subtitle': 'From quick 15-minute skillet bites to gourmet feasts matching your pantry ingredients.',
      'type': 'pantry_cards',
    },
  ];

  void _onFinish() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F12) : const Color(0xFFFBFBFD),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: CookTalk Brand Header + Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF143826),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.soup_kitchen_rounded,
                          color: Color(0xFFD2E68B),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CookTalk',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF143826),
                          letterSpacing: -0.6,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _onFinish,
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white60 : const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Middle Carousel Area (Matching Klava floating card visuals)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (context, idx) {
                  final slide = _slides[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const Spacer(flex: 1),

                        // Visual Artwork Area (Klava floating notification style / graphic)
                        Expanded(
                          flex: 12,
                          child: Center(
                            child: _buildVisualGraphic(slide['type'] as String, isDark),
                          ),
                        ),

                        const Spacer(flex: 1),

                        // Category Tag Pill (e.g. Save Drop / Earn Percentage in Klava)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: isDark
                                ? (slide['tagBg'] as Color).withValues(alpha: 0.2)
                                : slide['tagBg'] as Color,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            slide['tag'] as String,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : slide['tagColor'] as Color,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Title with tight bold line heights (Klava typography)
                        Text(
                          slide['title'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF143826),
                            letterSpacing: -0.8,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Subtitle
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            slide['subtitle'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.45,
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),

                        const Spacer(flex: 2),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Page Indicator Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? const Color(0xFF143826)
                        : (isDark ? Colors.white24 : const Color(0xFFD1D5DB)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Bottom Full-Width Pill Action Button (Matching Klava's Deep Forest Green)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _slides.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _onFinish();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
                    foregroundColor: isDark ? const Color(0xFF143826) : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    _currentPage == _slides.length - 1 ? 'Get Started' : 'Continue',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Visual artwork widgets matching the Klava reference (stacked notification pill cards & modern badges)
  Widget _buildVisualGraphic(String type, bool isDark) {
    if (type == 'stacked_cards') {
      return SizedBox(
        width: 320,
        height: 220,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Bottom 3rd Card (Dark Slate / Purple accent)
            Positioned(
              top: 130,
              child: _buildKlavaCard(
                iconColor: const Color(0xFF2C1654),
                icon: Icons.auto_awesome,
                title: 'You asked: "What can replace cream?"',
                time: 'CookTalk: "Greek yogurt or coconut milk work perfectly!"',
                isDark: isDark,
              ),
            ),
            // Middle 2nd Card (Cobalt Blue accent)
            Positioned(
              top: 65,
              child: _buildKlavaCard(
                iconColor: const Color(0xFF0D47A1),
                icon: Icons.timer_rounded,
                title: 'Steak resting timer completed',
                time: 'Resting for 5 minutes done. Ready to carve! 🥩',
                isDark: isDark,
              ),
            ),
            // Top 1st Card (Vibrant CookTalk Green accent)
            Positioned(
              top: 0,
              child: _buildKlavaCard(
                iconColor: const Color(0xFF143826),
                icon: Icons.soup_kitchen_rounded,
                title: 'Step 3: Sear the garlic butter prawns',
                time: 'Guidance active • Next step ready in 90 seconds 🍤',
                isDark: isDark,
              ),
            ),
          ],
        ),
      );
    } else if (type == 'graphic_badge') {
      return Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF143826).withValues(alpha: 0.1),
              const Color(0xFFD2E68B).withValues(alpha: 0.2),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF143826).withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF143826),
                ),
                child: const Icon(
                  Icons.mic_none_rounded,
                  size: 64,
                  color: Color(0xFFD2E68B),
                ),
              ),
              Positioned(
                top: 15,
                right: 15,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD2E68B),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.timer, color: Color(0xFF143826), size: 18),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Pantry & Dish Cards
      return Container(
        width: 260,
        height: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161922) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF2B3448) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=150&q=80',
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Steak & Herb Butter',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF143826),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Matches 95% of your pantry',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 22),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826)).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826)).withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mic,
                    size: 16,
                    color: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Say "Let\'s start cooking"',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildKlavaCard({
    required Color iconColor,
    required IconData icon,
    required String title,
    required String time,
    required bool isDark,
  }) {
    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161A22) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF263042) : const Color(0xFFEDF2F7),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    );
  }
}

