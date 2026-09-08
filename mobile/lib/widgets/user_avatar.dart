import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/supabase_config.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? username;
  final double size;
  final Color? borderColor;
  final double borderWidth;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    this.username,
    this.size = 44.0,
    this.borderColor,
    this.borderWidth = 1.5,
  });

  bool _isSvg(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.svg') ||
        lower.contains('api.dicebear.com') ||
        lower.contains('/svg');
  }

  bool _isDeprecatedUnsplash(String? url) {
    if (url == null || url.isEmpty) return true;
    return url.contains('photo-1534528741775-53994a69daeb');
  }

  String _getEffectiveUrl() {
    if (avatarUrl != null &&
        avatarUrl!.trim().isNotEmpty &&
        !_isDeprecatedUnsplash(avatarUrl)) {
      return avatarUrl!.trim();
    }
    return SupabaseConfig.getDiceBearAvatar(username ?? 'Samantha');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveUrl = _getEffectiveUrl();
    final defaultBorder = isDark ? Colors.white24 : const Color(0xFFE2E8F0);
    final resolvedBorderColor = borderColor ?? defaultBorder;
    final fallbackUrl = SupabaseConfig.getDiceBearAvatar(username ?? 'Samantha');

    Widget avatarImage;

    if (_isSvg(effectiveUrl)) {
      avatarImage = SvgPicture.network(
        effectiveUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => Container(
          width: size,
          height: size,
          color: isDark ? const Color(0xFF1E232B) : const Color(0xFFF1F5F9),
          child: Center(
            child: SizedBox(
              width: size * 0.4,
              height: size * 0.4,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    } else {
      avatarImage = Image.network(
        effectiveUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => SvgPicture.network(
          fallbackUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: size,
            height: size,
            color: isDark ? const Color(0xFF1E232B) : const Color(0xFFF1F5F9),
            child: Center(
              child: SizedBox(
                width: size * 0.4,
                height: size * 0.4,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? const Color(0xFF1E232B) : const Color(0xFFE9EDDF),
        border: Border.all(
          color: resolvedBorderColor,
          width: borderWidth,
        ),
      ),
      child: ClipOval(
        child: avatarImage,
      ),
    );
  }
}
