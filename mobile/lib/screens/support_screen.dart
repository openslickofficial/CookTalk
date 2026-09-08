import 'package:flutter/material.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final Set<int> _expandedIndices = {1}; // Default item 1 open as in reference mockup

  final List<Map<String, String>> _allFaqs = [
    {
      'question': 'How do I cancel or check an active voice timer?',
      'answer':
          'Simply say "Hey CookTalk, how much time is left on the pasta?" or "Cancel the steak timer." You can also tap the active timer pill on the cooking session screen directly.'
    },
    {
      'question': 'How does CookTalk filter out kitchen exhaust fan noise?',
      'answer':
          'CookTalk uses Silero Voice Activity Detection (VAD) tuned specifically for ambient acoustic patterns. You can adjust the sensitivity to "Exhaust Fan / High Noise" in Chef Profile > Kitchen Noise Filter.'
    },
    {
      'question': 'Can I change between Metric (grams) and Imperial (cups)?',
      'answer':
          'Yes! Toggle the Measurement System switch in Chef Profile > Voice & Kitchen Preferences. The AI assistant will automatically convert units when reading recipes aloud.'
    },
    {
      'question': 'What if the assistant suggests an ingredient I am allergic to?',
      'answer':
          'Say "I am allergic to dairy, what can I substitute?" The assistant will cross-reference pantry alternatives such as oat milk, coconut oil, or nutritional yeast in real-time.'
    },
    {
      'question': 'How do I permanently delete my account and data?',
      'answer':
          'Navigate to Chef Profile > Delete Account. Type "DELETE" into the verification input to permanently remove your profile, saved recipes, and voice history.'
    },
    {
      'question': 'How do I connect external Bluetooth kitchen speakers?',
      'answer':
          'Pair your Bluetooth speaker in your phone settings. CookTalk will route both audio output and mic input through your speaker with built-in echo cancellation.'
    },
  ];

  List<Map<String, String>> get _filteredFaqs {
    return _allFaqs;
  }

  void _openContactSupportModal() {
    final messageController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        final isDark = Theme.of(modalCtx).brightness == Brightness.dark;
        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(modalCtx).viewInsets.bottom + 28,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161A24) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Email Culinary Support',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF143826),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Send a message to our chef support team at support@cooktalk.ai',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 4,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
                decoration: InputDecoration(
                  hintText: 'Describe your issue or kitchen feedback...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0D0F12) : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF263042) : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (messageController.text.trim().isEmpty) return;
                    Navigator.of(modalCtx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Support request sent! We will reply to your email.'),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826),
                    foregroundColor: isDark ? const Color(0xFF143826) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Send Email', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openCallNowModal() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.phone, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text('Connecting to CookTalk Support: +1 (800) 555-COOK')),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF143826);
    final bodyTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final metaTextColor = isDark ? Colors.white54 : const Color(0xFF94A3B8);
    final accentLime = isDark ? const Color(0xFFD2E68B) : const Color(0xFF143826);
    final pillBorderColor = isDark ? const Color(0xFF2E384D) : const Color(0xFFCBD5E1);

    final faqs = _filteredFaqs;

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
          'Help & Support',
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
            // Big Two-Line Headline
            Text(
              'How can we\nHelp you today?',
              style: TextStyle(
                fontSize: 28,
                height: 1.25,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 20),

            // Two Action Buttons: Email Support & Call Now
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _openContactSupportModal,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: accentLime.withValues(alpha: 0.7),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.mail_outline_rounded,
                            color: accentLime,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Email Support',
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
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: GestureDetector(
                    onTap: _openCallNowModal,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: accentLime.withValues(alpha: 0.7),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            color: accentLime,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Call Now',
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
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Frequent Question Header
            Text(
              'Frequent Question',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Quick answers to common questions and kitchen guidance.',
              style: TextStyle(
                fontSize: 12.5,
                color: metaTextColor,
              ),
            ),
            const SizedBox(height: 16),

            // Accordion List matching reference UI
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: faqs.length,
              separatorBuilder: (_, __) => Divider(
                color: isDark ? const Color(0xFF263042) : const Color(0xFFF1F5F9),
                height: 24,
              ),
              itemBuilder: (context, index) {
                final faq = faqs[index];
                final isExpanded = _expandedIndices.contains(index);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedIndices.remove(index);
                          } else {
                            _expandedIndices.add(index);
                          }
                        });
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              faq['question']!,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: metaTextColor,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                    if (isExpanded) ...[
                      const SizedBox(height: 10),
                      Text(
                        faq['answer']!,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.55,
                          color: bodyTextColor,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
