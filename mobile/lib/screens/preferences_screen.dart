import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'main_nav_screen.dart';

// ============================================================================
// SCREEN 1: "What do you love cooking?" (Cuisines Selection - Minimum 3)
// ============================================================================

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final Set<String> _selectedCuisines = {'Italian', 'Asian', 'American'};

  final List<Map<String, dynamic>> _cuisines = [
    {'name': 'Italian', 'icon': '🍕'},
    {'name': 'Asian', 'icon': '🥢'},
    {'name': 'Mexican', 'icon': '🌮'},
    {'name': 'Indian', 'icon': '🍛'},
    {'name': 'Mediterranean', 'icon': '🫒'},
    {'name': 'American', 'icon': '🍔'},
    {'name': 'French', 'icon': '🥐'},
    {'name': 'Japanese', 'icon': '🍣'},
    {'name': 'Thai', 'icon': '🍜'},
    {'name': 'Middle Eastern', 'icon': '🧆'},
    {'name': 'Healthy / Clean', 'icon': '🥗'},
    {'name': 'Seafood', 'icon': '🦐'},
  ];

  bool get _isValid => _selectedCuisines.length >= 3;

  void _goToFrequencyScreen() {
    if (!_isValid) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CookingFrequencyScreen(
          selectedCuisines: _selectedCuisines.toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F12) : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // Title
                    Text(
                      'What do you love cooking?',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF143826),
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle & Validation Counter Pill
                    Row(
                      children: [
                        Text(
                          'Select at least 3 favorite cuisines',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isValid
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_selectedCuisines.length}/3 selected',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _isValid ? const Color(0xFF10B981) : Colors.amber[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Cuisines Badges Wrap
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _cuisines.map((c) {
                        final name = c['name'] as String;
                        final icon = c['icon'] as String;
                        final isSelected = _selectedCuisines.contains(name);

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedCuisines.remove(name);
                              } else {
                                _selectedCuisines.add(name);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF143826)
                                  : (isDark ? const Color(0xFF1A1F2B) : Colors.white),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF143826)
                                    : (isDark ? const Color(0xFF2A3447) : const Color(0xFFE2E8F0)),
                                width: 1.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF143826).withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(icon, style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFFD2E68B), size: 16),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Continue Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isValid ? _goToFrequencyScreen : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
                    disabledBackgroundColor: isDark ? Colors.white12 : Colors.black12,
                    foregroundColor: isDark ? const Color(0xFF143826) : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    _isValid ? 'Continue' : 'Select at least 3 cuisines',
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
}

// ============================================================================
// SCREEN 2: "Do you cook often?" (Cooking Frequency Selection)
// ============================================================================

class CookingFrequencyScreen extends StatefulWidget {
  final List<String> selectedCuisines;

  const CookingFrequencyScreen({
    super.key,
    required this.selectedCuisines,
  });

  @override
  State<CookingFrequencyScreen> createState() => _CookingFrequencyScreenState();
}

class _CookingFrequencyScreenState extends State<CookingFrequencyScreen> {
  String _selectedFrequency = 'A few times a week';
  bool _isSaving = false;

  final List<Map<String, String>> _frequencies = [
    {'title': 'Rarely / Beginner', 'desc': 'Just starting to explore cooking'},
    {'title': 'A few times a week', 'desc': 'Cook simple and balanced meals'},
    {'title': 'Daily Home Chef', 'desc': 'Cook almost every single day'},
    {'title': 'Passionate Gourmet', 'desc': 'Love experimenting with complex dishes'},
  ];

  Future<void> _handleComplete() async {
    setState(() => _isSaving = true);

    await SupabaseService.instance.savePreferences(
      favoriteCuisines: widget.selectedCuisines,
      cookingFrequency: _selectedFrequency,
    );

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F12) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      'Do you cook often?',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF143826),
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Helps CookTalk gauge the level of detail in instructions',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Frequency Badges
                    Column(
                      children: _frequencies.map((f) {
                        final title = f['title']!;
                        final desc = f['desc']!;
                        final isSelected = _selectedFrequency == title;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedFrequency = title),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark
                                      ? const Color(0xFFD2E68B).withValues(alpha: 0.12)
                                      : const Color(0xFF143826).withValues(alpha: 0.08))
                                  : (isDark ? const Color(0xFF161A24) : Colors.white),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826))
                                    : (isDark ? const Color(0xFF263042) : const Color(0xFFE2E8F0)),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? (isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826))
                                          : (isDark ? Colors.white30 : Colors.black26),
                                      width: 2,
                                    ),
                                    color: isSelected
                                        ? (isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826))
                                        : Colors.transparent,
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Icon(
                                            Icons.circle,
                                            size: 9,
                                            color: isDark ? const Color(0xFF143826) : Colors.white,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        desc,
                                        style: TextStyle(
                                          fontSize: 13,
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
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Complete Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
                    foregroundColor: isDark ? const Color(0xFF143826) : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: isDark ? const Color(0xFF143826) : Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Complete & Start Cooking',
                          style: TextStyle(
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
}
