import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'auth_screen.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _confirmationController = TextEditingController();
  bool _isDeleting = false;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _confirmationController.addListener(() {
      final isMatch = _confirmationController.text.trim().toUpperCase() == 'DELETE';
      if (isMatch != _confirmed) {
        setState(() => _confirmed = isMatch);
      }
    });
  }

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _executeAccountDeletion() async {
    if (!_confirmed || _isDeleting) return;

    setState(() => _isDeleting = true);

    try {
      await SupabaseService.instance.deleteAccount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Your account and associated data have been permanently deleted.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during account deletion: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF143826);
    final bodyTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final metaTextColor = isDark ? Colors.white54 : const Color(0xFF94A3B8);
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
          'Delete Account',
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
              'Delete Account',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.redAccent,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),

            // Version Pill & Notice Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'Permanent & Irreversible',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Immediate Wiping',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: metaTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Paragraph 1: Warning
            Text(
              'Deleting your CookTalk account will immediately erase all your personal data, personalized chef preferences, saved recipe collections, and AI voice interaction logs.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: bodyTextColor,
              ),
            ),
            const SizedBox(height: 16),

            // Paragraph 2: What is removed
            Text(
              'Upon confirmation, the following will be permanently removed from our Supabase servers and your local storage:',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 10),

            _buildBulletPoint('• User profile, email authentication, and display name', bodyTextColor),
            _buildBulletPoint('• Curated favorites and bookmarked recipes', bodyTextColor),
            _buildBulletPoint('• AI voice sous-chef session logs and recently viewed dishes', bodyTextColor),
            _buildBulletPoint('• Favorite cuisines, cooking tier, and measurement settings', bodyTextColor),

            const SizedBox(height: 24),

            // Paragraph 3: Confirmation instruction
            Text(
              'To confirm that you want to delete your account permanently, type "DELETE" below:',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _confirmationController,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: primaryTextColor,
              ),
              decoration: InputDecoration(
                hintText: 'DELETE',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                  letterSpacing: 1.2,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF161A24) : const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF263042) : const Color(0xFFCBD5E1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF263042) : const Color(0xFFCBD5E1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Execution Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_confirmed && !_isDeleting) ? _executeAccountDeletion : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  disabledBackgroundColor: isDark ? const Color(0xFF1E232B) : const Color(0xFFF1F5F9),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: isDark ? Colors.white24 : const Color(0xFF94A3B8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 0,
                ),
                child: _isDeleting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Permanently Delete Account',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
              ),
            ),

            const SizedBox(height: 14),

            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel and Return',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: metaTextColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color: textColor,
        ),
      ),
    );
  }
}
