import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import 'preferences_screen.dart';
import 'main_nav_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isAppleLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;

  bool get _isLoading => _isAppleLoading || _isGoogleLoading;

  @override
  void initState() {
    super.initState();
    SupabaseService.instance.authStateNotifier.addListener(_onAuthStateChanged);
  }

  @override
  void dispose() {
    SupabaseService.instance.authStateNotifier.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    final profile = SupabaseService.instance.currentUser;
    if (profile != null && mounted) {
      if (!profile.onboardingCompleted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PreferencesScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavScreen()),
        );
      }
    }
  }

  Future<void> _handleSignIn({required bool isApple}) async {
    setState(() {
      if (isApple) {
        _isAppleLoading = true;
      } else {
        _isGoogleLoading = true;
      }
      _errorMessage = null;
    });

    try {
      final profile = isApple
          ? await SupabaseService.instance.signInWithApple()
          : await SupabaseService.instance.signInWithGoogle();

      if (!mounted) return;

      if (profile != null) {
        if (!profile.onboardingCompleted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PreferencesScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Authentication failed. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isApple) {
            _isAppleLoading = false;
          } else {
            _isGoogleLoading = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isDark ? const Color(0xFF0D0F13) : Colors.white;
    final headlineColor = isDark ? Colors.white : const Color(0xFF143826);
    final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF64748B);
    final buttonBg = isDark ? const Color(0xFF1B1F27) : Colors.white;
    final buttonBorder = isDark ? const Color(0xFF2E3544) : const Color(0xFFE2E8F0);
    final appleTextColor = isDark ? Colors.white : Colors.black;
    final googleTextColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final legalTextColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF64748B);
    final legalLinkColor = isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF143826);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // 1. HERO IMAGE WITH SMOOTH GRADIENT FADE (covers top 58% of screen)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.58,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  'https://images.unsplash.com/photo-1556910103-1c02745aae4d?auto=format&fit=crop&w=1200&q=85',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => Container(
                    color: isDark ? const Color(0xFF181C23) : const Color(0xFFF1F5F9),
                  ),
                ),
                // Smooth downward gradient fade matching theme
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.35, 0.65, 0.88, 1.0],
                      colors: isDark
                          ? [
                              Colors.black.withValues(alpha: 0.35),
                              Colors.transparent,
                              backgroundColor.withValues(alpha: 0.45),
                              backgroundColor.withValues(alpha: 0.88),
                              backgroundColor,
                            ]
                          : [
                              Colors.black.withValues(alpha: 0.10),
                              Colors.transparent,
                              backgroundColor.withValues(alpha: 0.45),
                              backgroundColor.withValues(alpha: 0.90),
                              backgroundColor,
                            ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. FOREGROUND CONTENT (Shifted upward into the gradient)
          SafeArea(
            child: Column(
              children: [
                // Spacer pushes content upward so headline sits over the gradient fade
                const Spacer(flex: 3),

                // Main Content Block
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Headline (moved upward, without 3 indicator lines)
                      Text(
                        'Welcome to CookTalk 👋',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: headlineColor,
                          letterSpacing: -0.6,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Subtitle
                      Text(
                        'The best cooking and food recipes\napp of the century.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          height: 1.45,
                          color: subtitleColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_errorMessage != null) ...[
                        Text(
                          _errorMessage!,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // BUTTON 1: Continue with Apple
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => _handleSignIn(isApple: true),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: buttonBg,
                            foregroundColor: appleTextColor,
                            side: BorderSide(
                              color: buttonBorder,
                              width: 1.2,
                            ),
                            elevation: isDark ? 0 : 0.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: _isAppleLoading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: appleTextColor,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.apple,
                                      size: 22,
                                      color: appleTextColor,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Continue with Apple',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: appleTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // BUTTON 2: Continue with Google
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => _handleSignIn(isApple: false),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: buttonBg,
                            foregroundColor: googleTextColor,
                            side: BorderSide(
                              color: buttonBorder,
                              width: 1.2,
                            ),
                            elevation: isDark ? 0 : 0.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: _isGoogleLoading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: googleTextColor,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/google.png',
                                      width: 20,
                                      height: 20,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 20,
                                        height: 20,
                                        decoration: const BoxDecoration(shape: BoxShape.circle),
                                        child: const Center(
                                          child: Text(
                                            'G',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF4285F4),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Continue with Google',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: googleTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ACCEPTANCE TEXT (Cleanly formatted across 2 lines)
                      Text.rich(
                        TextSpan(
                          text: 'By continuing, you agree to our ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: legalTextColor,
                            height: 1.45,
                          ),
                          children: [
                            TextSpan(
                              text: 'Terms of Service',
                              style: GoogleFonts.plusJakartaSans(
                                color: legalLinkColor,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(text: ' and\n'),
                            TextSpan(
                              text: 'acknowledge that you have read our ',
                              style: GoogleFonts.plusJakartaSans(
                                color: legalTextColor,
                              ),
                            ),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: GoogleFonts.plusJakartaSans(
                                color: legalLinkColor,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Bottom breathing room
                const Spacer(flex: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

