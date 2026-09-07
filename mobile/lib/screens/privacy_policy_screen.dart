import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF143826);
    final bodyTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final metaTextColor = isDark ? Colors.white54 : const Color(0xFF94A3B8);
    final accentLime = isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826);
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
          'Privacy Policy',
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
              'Privacy Policy',
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
                    color: accentLime.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_circle_down_rounded,
                      color: accentLime,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Download as PDF',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: accentLime,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Paragraph 1: Commitment & Overview
            Text(
              'Protecting your privacy is a top priority at CookTalk. We understand that you entrust us with your personal kitchen routines, dietary preferences, and audio interactions, and we take that responsibility with the utmost diligence and security.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: bodyTextColor,
              ),
            ),
            const SizedBox(height: 16),

            // Paragraph 2: Real-time Voice & Zero Selling
            Text(
              'When you use our hands-free cooking assistant, your spoken voice input is streamed securely in real-time over WebRTC encrypted tunnels directly to our speech recognition pipeline (Deepgram nova-3). We process audio strictly in ephemeral memory to interpret culinary commands and never sell, license, or store your biometric voice recordings.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: bodyTextColor,
              ),
            ),
            const SizedBox(height: 16),

            // Paragraph 3: Data Collected in Database
            Text(
              'We collect and store only the data necessary to personalize your recipes and kitchen preferences: your account credentials, dietary restrictions, favorite cuisines, and saved cookbooks stored in our encrypted Supabase database. We do not track your activity outside of CookTalk.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: bodyTextColor,
              ),
            ),
            const SizedBox(height: 16),

            // Paragraph 4: Third-Party Infrastructure
            Text(
              'To deliver sub-second response times, we integrate with industry-leading infrastructure providers: LiveKit Cloud for WebRTC audio transport, Deepgram for speech-to-text, Groq for neural recipe reasoning, and Rime Labs for voice synthesis. All providers comply with rigorous global data privacy and encryption standards.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: bodyTextColor,
              ),
            ),
            const SizedBox(height: 16),

            // Paragraph 5: User Rights & App Store Compliance
            Text(
              'In strict adherence to Apple App Store Guideline 5.1.1 and Google Play Store User Data policies, you maintain total ownership of your data. You may request a data export or permanently delete your account and all associated culinary history at any time directly through the app (Chef Profile > Delete Account).',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: bodyTextColor,
              ),
            ),
            const SizedBox(height: 16),

            // Paragraph 6: Contact
            Text(
              'If you have any questions or concerns regarding our privacy practices, please contact our Data Protection Officer at privacy@cooktalk.ai. Your trust is essential to us, and we are committed to ensuring your peace of mind in the kitchen.',
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
