import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _confirmationController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isProcessing = false;
  bool _confirmed = false;
  Map<String, dynamic>? _deletionStatus;
  bool _isLoadingStatus = true;

  @override
  void initState() {
    super.initState();
    _confirmationController.addListener(() {
      final isMatch = _confirmationController.text.trim().toUpperCase() == 'DELETE';
      if (isMatch != _confirmed) {
        setState(() => _confirmed = isMatch);
      }
    });
    _checkDeletionStatus();
  }

  Future<void> _checkDeletionStatus() async {
    setState(() => _isLoadingStatus = true);
    try {
      final status = await SupabaseService.instance.getDeletionStatus();
      if (mounted) {
        setState(() {
          _deletionStatus = status;
          _isLoadingStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStatus = false);
      }
    }
  }

  @override
  void dispose() {
    _confirmationController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _requestAccountDeletion() async {
    if (!_confirmed || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final result = await SupabaseService.instance.requestAccountDeletion(
        reason: _reasonController.text.trim().isNotEmpty 
            ? _reasonController.text.trim() 
            : null,
      );

      if (mounted && result['success'] == true) {
        final scheduledAt = result['scheduled_deletion_at'] as DateTime;
        final daysRemaining = result['days_remaining'] ?? 7;

        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.schedule, color: Color(0xFFEF4444)),
                SizedBox(width: 12),
                Text('Deletion Scheduled'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your account is scheduled for deletion on:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  '${scheduledAt.day}/${scheduledAt.month}/${scheduledAt.year} at ${scheduledAt.hour}:${scheduledAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                ),
                SizedBox(height: 16),
                Text('You have $daysRemaining days to cancel this request.'),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Color(0xFFF59E0B)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Logging in will automatically cancel deletion',
                          style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Return to profile screen
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scheduling deletion: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _cancelDeletion() async {
    setState(() => _isProcessing = true);

    try {
      final success = await SupabaseService.instance.cancelAccountDeletion();

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Account deletion cancelled successfully!'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(); // Return to profile
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to cancel deletion'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
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

    if (_isLoadingStatus) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0D0F12) : Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Delete Account'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // If deletion already scheduled, show cancellation screen
    if (_deletionStatus != null) {
      return _buildCancellationScreen(isDark, primaryTextColor, bodyTextColor, metaTextColor);
    }

    // Otherwise show deletion request screen
    return _buildDeletionRequestScreen(isDark, primaryTextColor, bodyTextColor, metaTextColor);
  }

  Widget _buildCancellationScreen(
    bool isDark,
    Color primaryTextColor,
    Color bodyTextColor,
    Color metaTextColor,
  ) {
    final scheduledAt = _deletionStatus!['scheduled_deletion_at'] as DateTime;
    final daysRemaining = _deletionStatus!['days_remaining'] as int;
    final hoursRemaining = _deletionStatus!['hours_remaining'] as int;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F12) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryTextColor, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Account Deletion Scheduled',
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
            // Warning Icon
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.schedule,
                  size: 40,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Center(
              child: Text(
                'Deletion Scheduled',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFEF4444),
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Countdown Badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Text(
                  daysRemaining > 0 
                      ? '$daysRemaining days remaining'
                      : '$hoursRemaining hours remaining',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Scheduled Date/Time
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161A24) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF263042) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your account will be permanently deleted on:',
                    style: TextStyle(fontSize: 13, color: metaTextColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${scheduledAt.day}/${scheduledAt.month}/${scheduledAt.year}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
                    ),
                  ),
                  Text(
                    'at ${scheduledAt.hour}:${scheduledAt.minute.toString().padLeft(2, '0')} UTC',
                    style: TextStyle(
                      fontSize: 14,
                      color: bodyTextColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Info boxes
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 22, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Auto-Cancel on Login',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'If you log in during the grace period, deletion will be automatically cancelled.',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF92400E).withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Cancel Deletion Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _cancelDeletion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  disabledBackgroundColor: isDark ? const Color(0xFF1E232B) : const Color(0xFFF1F5F9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(27),
                  ),
                  elevation: 2,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Cancel Deletion & Keep My Account',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Go Back',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

  Widget _buildDeletionRequestScreen(
    bool isDark,
    Color primaryTextColor,
    Color bodyTextColor,
    Color metaTextColor,
  ) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F12) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryTextColor, size: 22),
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
            // Title
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

            // 7-Day Grace Period Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                    color: const Color(0xFF10B981).withOpacity(0.1),
                  ),
                  child: const Text(
                    '7-Day Grace Period',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Can be cancelled',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: metaTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Info Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.schedule, size: 22, color: Color(0xFF059669)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your account won\'t be deleted immediately',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF065F46),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'You have 7 days to change your mind. Simply log in to cancel deletion automatically.',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF065F46).withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Warning
            Text(
              'After 7 days, the following will be permanently removed:',
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
            _buildBulletPoint('• AI voice session logs and cooking history', bodyTextColor),
            _buildBulletPoint('• Favorite cuisines and preference settings', bodyTextColor),
            _buildBulletPoint('• Your AI-generated recipes', bodyTextColor),

            const SizedBox(height: 24),

            // Optional Reason
            Text(
              'Help us improve (optional):',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _reasonController,
              maxLines: 3,
              style: TextStyle(fontSize: 14, color: primaryTextColor),
              decoration: InputDecoration(
                hintText: 'Why are you leaving? (optional)',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF161A24) : const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.all(14),
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
                  borderSide: const BorderSide(color: Color(0xFFD2E68B), width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Confirmation
            Text(
              'To confirm, type "DELETE" below:',
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

            const SizedBox(height: 24),

            // Request Deletion Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_confirmed && !_isProcessing) ? _requestAccountDeletion : null,
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
                child: _isProcessing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Schedule Deletion (7 days)',
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
