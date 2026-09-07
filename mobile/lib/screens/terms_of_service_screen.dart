import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF143826);
    final bodyTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final metaTextColor = isDark ? Colors.white54 : const Color(0xFF94A3B8);
    final accentGreen = isDark ? const Color(0xFFD2E68B) : const Color(0xFF10B981);
    final pillBorderColor = isDark ? const Color(0xFF2E384D) : const Color(0xFFCBD5E1);

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
          'Terms of use',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: primaryTextColor,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Big Screen Title
            Text(
              'Terms of Service',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),

            // Version Pill & Published Date Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: pillBorderColor),
                  ),
                  child: Text(
                    'v2.1.0',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: metaTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Published on September, 2026',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: metaTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Download as PDF Button
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Preparing PDF download for offline viewing...'),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: accentGreen.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_circle_down_rounded,
                      color: accentGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Download as PDF',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: accentGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Paragraph 1: Acceptance & Welcome
            Text(
              'Welcome to CookTalk. By accessing our mobile application, creating a chef profile, or utilizing our interactive voice assistant, you agree to comply with and be bound by the following Terms of Service.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: bodyTextColor,
              ),
            ),
            const SizedBox(height: 16),

            // Paragraph 2: Culinary & Health Safety Notice
            Text(
              'CookTalk provides artificial intelligence assistive technology designed to facilitate hands-free cooking. All recipe instructions, preparation timings, allergen alerts, and cooking temperatures are generated as culinary guidance. Users must independently verify food freshness, safe internal meat temperatures (USDA/FDA standards), and personal dietary restrictions.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: bodyTextColor,
              ),
            ),
            const SizedBox(height: 16),

            // Paragraph 3: Kitchen Safety & Utensils
            Text(
              'Cooking inherently involves hazardous tools including open flames, boiling liquids, hot grease, pressure cookers, and sharp cutlery. You remain solely responsible for maintaining vigilance and personal safety in your kitchen. Voice timers and reminders must not replace physical attention around active heat sources.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: bodyTextColor,
              ),
            ),
            const SizedBox(height: 16),

            // Paragraph 4: Streaming Voice API Fair Use
            Text(
              'CookTalk utilizes shared neural computing infrastructure to deliver ultra-low latency voice responses. Any automated reverse engineering, token scraping, denial-of-service attempts, or continuous artificial streaming intended to exhaust server capacity is strictly prohibited and will result in account termination.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: bodyTextColor,
              ),
            ),
            const SizedBox(height: 16),

            // Paragraph 5: Limitation of Liability
            Text(
              'To the fullest extent permitted by applicable law, CookTalk and its developers disclaim any liability for kitchen injuries, spoiled ingredients, equipment damage, allergic reactions, or foodborne illnesses arising from reliance on recipe steps or voice sous-chef recommendations.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: bodyTextColor,
              ),
            ),
            const SizedBox(height: 16),

            // Paragraph 6: Inquiries
            Text(
              'If you have questions regarding these terms, our culinary guidelines, or compliance standards, please reach out to our legal department at legal@cooktalk.ai.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: bodyTextColor,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
