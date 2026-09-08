import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF143826);
    final bodyTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final metaTextColor = isDark ? Colors.white54 : const Color(0xFF94A3B8);
    final dividerColor = isDark ? const Color(0xFF263042) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F12) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: primaryTextColor,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'About CookTalk',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: primaryTextColor,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Logo/Icon
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/app_icon.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.fill,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF143826),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.soup_kitchen_rounded,
                        color: Color(0xFFD2E68B),
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // App Name & Version
            Center(
              child: Column(
                children: [
                  Text(
                    'CookTalk',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 13,
                      color: metaTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Tagline
            Center(
              child: Text(
                'Your AI Voice Cooking Assistant',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: bodyTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 32),
            Divider(color: dividerColor, height: 1),
            const SizedBox(height: 32),

            // About Section
            Text(
              'About',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'CookTalk is a revolutionary hands-free cooking companion that uses advanced voice AI to guide you through recipes step-by-step. Whether you\'re a beginner or a seasoned chef, CookTalk makes cooking easier, cleaner, and more enjoyable.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: bodyTextColor,
              ),
            ),

            const SizedBox(height: 28),

            // Features Section
            Text(
              'Features',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              '🎙️ Voice-Controlled Cooking',
              'Navigate recipes entirely hands-free with natural voice commands',
              isDark,
              bodyTextColor,
            ),
            _buildFeatureItem(
              '⏲️ Smart Timers',
              'Set and manage multiple cooking timers without touching your phone',
              isDark,
              bodyTextColor,
            ),
            _buildFeatureItem(
              '🔄 Ingredient Substitutions',
              'Get instant alternatives for ingredients you don\'t have',
              isDark,
              bodyTextColor,
            ),
            _buildFeatureItem(
              '📚 Curated Recipe Library',
              'Access thousands of recipes tailored to your preferences',
              isDark,
              bodyTextColor,
            ),
            _buildFeatureItem(
              '🌙 Dark Mode Support',
              'Comfortable viewing in any lighting condition',
              isDark,
              bodyTextColor,
            ),

            const SizedBox(height: 28),

            // Company Info
            Text(
              'Company',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'CookTalk is developed by a passionate team dedicated to making cooking accessible and enjoyable for everyone. We believe that technology should enhance the cooking experience, not complicate it.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: bodyTextColor,
              ),
            ),

            const SizedBox(height: 28),

            // Contact Section
            Text(
              'Contact Us',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 12),
            _buildContactItem(Icons.email_outlined, 'support@cooktalk.ai', isDark, bodyTextColor),
            _buildContactItem(Icons.language_rounded, 'www.cooktalk.ai', isDark, bodyTextColor),
            _buildContactItem(Icons.location_on_outlined, 'Bongaigaon, Assam, India', isDark, bodyTextColor),

            const SizedBox(height: 32),
            Divider(color: dividerColor, height: 1),
            const SizedBox(height: 24),

            // Copyright
            Center(
              child: Text(
                '© 2024 CookTalk. All rights reserved.',
                style: TextStyle(
                  fontSize: 12,
                  color: metaTextColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Made with ❤️ for home chefs everywhere',
                style: TextStyle(
                  fontSize: 12,
                  color: metaTextColor,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description, bool isDark, Color bodyTextColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: bodyTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String text, bool isDark, Color bodyTextColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: bodyTextColor,
            ),
          ),
        ],
      ),
    );
  }
}
