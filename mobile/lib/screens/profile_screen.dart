import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';
import 'auth_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import 'support_screen.dart';
import 'account_deletion_screen.dart';

class ProfileScreen extends StatefulWidget {
  final ValueNotifier<ThemeMode> appThemeMode;

  const ProfileScreen({super.key, required this.appThemeMode});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final List<Map<String, String>> _cuisinePool = [
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

  final List<String> _skillLevels = [
    'Rarely / Beginner',
    'A few times a week',
    'Daily Home Chef',
    'Passionate Gourmet',
  ];

  final List<Map<String, String>> _voiceOptions = [
    {'id': 'Astra', 'name': 'Astra', 'desc': 'Natural, warm, upbeat sous-chef'},
    {'id': 'Coda', 'name': 'Coda', 'desc': 'Crisp, articulate culinary pacing'},
    {'id': 'Warm Chef', 'name': 'Warm Chef', 'desc': 'Friendly, encouraging kitchen guide'},
    {'id': 'Direct Chef', 'name': 'Direct Chef', 'desc': 'Concise, rapid-fire instruction'},
  ];

  final List<Map<String, String>> _vadOptions = [
    {'id': 'Quiet', 'name': 'Quiet Kitchen', 'desc': 'High sensitivity for calm environments'},
    {'id': 'Standard', 'name': 'Standard', 'desc': 'Balanced ambient noise filtering'},
    {'id': 'Loud Kitchen', 'name': 'Exhaust Fan / High Noise', 'desc': 'Maximum noise isolation near stove'},
  ];

  void _openEditProfileModal(UserProfile profile) {
    final nameController = TextEditingController(text: profile.fullName);
    String selectedSkill = profile.cookingFrequency;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        final isDark = Theme.of(modalContext).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                MediaQuery.of(ctx).viewInsets.bottom + 28,
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
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF143826),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Display Name',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF4A5568),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0D0F12) : const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF263042) : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Cooking Skill Tier',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF4A5568),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _skillLevels.map((skill) {
                      final isSelected = selectedSkill == skill;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedSkill = skill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF7A00)
                                : (isDark ? const Color(0xFF222836) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            skill,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : const Color(0xFF4A5568)),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final newName = nameController.text.trim();
                        if (newName.isNotEmpty) {
                          await SupabaseService.instance.updateProfile(
                            fullName: newName,
                            cookingFrequency: selectedSkill,
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          setState(() {});
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7A00),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Save Profile Changes', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openCuisinesEditor(UserProfile profile) {
    final currentCuisines = Set<String>.from(profile.favoriteCuisines);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        final isDark = Theme.of(modalContext).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final count = currentCuisines.length;

            return Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Favorite Cuisines',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF143826),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: count >= 3
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count selected',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: count >= 3 ? const Color(0xFF10B981) : Colors.amber.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select cuisines to tune your voice assistant suggestions.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _cuisinePool.map((c) {
                      final name = c['name']!;
                      final icon = c['icon']!;
                      final isSelected = currentCuisines.contains(name);

                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            if (isSelected) {
                              currentCuisines.remove(name);
                            } else {
                              currentCuisines.add(name);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF143826)
                                : (isDark ? const Color(0xFF222836) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFD2E68B)
                                  : (isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0)),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(icon, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.check_rounded, color: Color(0xFFD2E68B), size: 14),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        await SupabaseService.instance.updateProfile(
                          favoriteCuisines: currentCuisines.toList(),
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7A00),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Update Cuisines', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openVoiceSelector() {
    final currentVoice = SupabaseService.instance.rimeVoiceStyle;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        final isDark = Theme.of(modalContext).brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
                'Rime Voice Character',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF143826),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Select the voice persona for your AI sous-chef.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              ..._voiceOptions.map((opt) {
                final isSelected = currentVoice == opt['id'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFF7A00).withValues(alpha: 0.12)
                        : (isDark ? const Color(0xFF222836) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFF7A00)
                          : (isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Icon(
                      Icons.record_voice_over_rounded,
                      color: isSelected ? const Color(0xFFFF7A00) : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                    ),
                    title: Text(
                      opt['name']!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    subtitle: Text(
                      opt['desc']!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFF7A00), size: 20)
                        : null,
                    onTap: () async {
                      await SupabaseService.instance.setRimeVoiceStyle(opt['id']!);
                      if (modalContext.mounted) Navigator.of(modalContext).pop();
                      setState(() {});
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _openVadSelector() {
    final currentVad = SupabaseService.instance.vadSensitivity;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        final isDark = Theme.of(modalContext).brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
                'Kitchen Noise Filter (Silero VAD)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF143826),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Configure acoustic background isolation for loud kitchen equipment.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              ..._vadOptions.map((opt) {
                final isSelected = currentVad == opt['id'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : (isDark ? const Color(0xFF222836) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF10B981)
                          : (isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Icon(
                      Icons.graphic_eq_rounded,
                      color: isSelected ? const Color(0xFF10B981) : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                    ),
                    title: Text(
                      opt['name']!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    subtitle: Text(
                      opt['desc']!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20)
                        : null,
                    onTap: () async {
                      await SupabaseService.instance.setVadSensitivity(opt['id']!);
                      if (modalContext.mounted) Navigator.of(modalContext).pop();
                      setState(() {});
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800)),
          content: const Text('Are you sure you want to sign out of CookTalk?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await SupabaseService.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profile = SupabaseService.instance.currentUser ??
        const UserProfile(
          id: 'demo-samantha-101',
          email: 'samantha.cooks@gmail.com',
          fullName: 'Samantha',
          avatarUrl:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
          favoriteCuisines: ['Italian', 'Asian', 'American'],
          cookingFrequency: 'Daily Home Chef',
          onboardingCompleted: true,
        );

    final currentVoice = SupabaseService.instance.rimeVoiceStyle;
    final isMetric = SupabaseService.instance.isMetric;
    final vadSensitivity = SupabaseService.instance.vadSensitivity;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F12) : const Color(0xFFF9FAF7),
      appBar: AppBar(
        title: Text(
          'Chef Profile',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.4,
            color: isDark ? Colors.white : const Color(0xFF143826),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 130),
        children: [
          // ==================================================================
          // SECTION 1: USER IDENTITY CARD
          // ==================================================================
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161A24) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0xFF263042) : const Color(0xFFECEFE8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFF7A00), width: 2),
                            image: DecorationImage(
                              image: NetworkImage(profile.avatarUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.fullName,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile.email,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Skill Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF7A00).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.restaurant_rounded, size: 12, color: Color(0xFFFF7A00)),
                                const SizedBox(width: 4),
                                Text(
                                  profile.cookingFrequency,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFF7A00),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () => _openEditProfileModal(profile),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text(
                      'Edit Profile',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : const Color(0xFF143826),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF2E384D) : const Color(0xFFCBD5E1),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ==================================================================
          // SECTION 2: VOICE & KITCHEN PREFERENCES
          // ==================================================================
          _buildSectionTitle('Voice & Kitchen Preferences', isDark: isDark),
          const SizedBox(height: 10),
          _buildCardContainer(
            isDark: isDark,
            children: [
              // Favorite Cuisines
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF143826),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(child: Text('🥗', style: TextStyle(fontSize: 18))),
                ),
                title: Text(
                  'Favorite Cuisines',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                subtitle: Text(
                  profile.favoriteCuisines.isNotEmpty
                      ? profile.favoriteCuisines.join(', ')
                      : 'Italian, Asian, American',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: () => _openCuisinesEditor(profile),
              ),
              _buildDivider(isDark),

              // Rime Voice Selector
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.record_voice_over_rounded, color: Color(0xFF8B5CF6), size: 20),
                ),
                title: Text(
                  'Rime Voice Character',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                subtitle: Text(
                  'Current: $currentVoice (Streaming WS)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: _openVoiceSelector,
              ),
              _buildDivider(isDark),

              // Measurement System (Metric vs Imperial)
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                secondary: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7A00).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.scale_rounded, color: Color(0xFFFF7A00), size: 20),
                ),
                title: Text(
                  'Measurement System',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                subtitle: Text(
                  isMetric ? 'Metric Units (Grams, ml, °C)' : 'Imperial Units (Cups, oz, °F)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                value: isMetric,
                activeTrackColor: const Color(0xFFFF7A00),
                onChanged: (val) async {
                  await SupabaseService.instance.setIsMetric(val);
                  setState(() {});
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ==================================================================
          // SECTION 3: APP SETTINGS & DISPLAY
          // ==================================================================
          _buildSectionTitle('App Settings & Display', isDark: isDark),
          const SizedBox(height: 10),
          _buildCardContainer(
            isDark: isDark,
            children: [
              // Theme Mode Selector
              ValueListenableBuilder<ThemeMode>(
                valueListenable: widget.appThemeMode,
                builder: (context, mode, _) {
                  final isOledDark = mode == ThemeMode.dark ||
                      (mode == ThemeMode.system &&
                          MediaQuery.platformBrightnessOf(context) == Brightness.dark);

                  return SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    secondary: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isOledDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: Colors.indigo,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Dark Appearance',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    subtitle: Text(
                      isOledDark ? 'OLED Dark (#0D0F12)' : 'Clean Light Theme',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                    value: isOledDark,
                    activeTrackColor: const Color(0xFFFF7A00),
                    onChanged: (val) {
                      widget.appThemeMode.value = val ? ThemeMode.dark : ThemeMode.light;
                    },
                  );
                },
              ),
              _buildDivider(isDark),

              // Audio Settings / Silero VAD Sensitivity
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.hearing_rounded, color: Color(0xFF10B981), size: 20),
                ),
                title: Text(
                  'Kitchen Noise Filter (VAD)',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                subtitle: Text(
                  'Current Mode: $vadSensitivity',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: _openVadSelector,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ==================================================================
          // SECTION 4: SUPPORT & LEGAL (APP STORE MANDATES)
          // ==================================================================
          _buildSectionTitle('Support & Legal (Store Compliance)', isDark: isDark),
          const SizedBox(height: 10),
          _buildCardContainer(
            isDark: isDark,
            children: [
              // Customer Care / Help Center
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.support_agent_rounded, color: Color(0xFF0EA5E9), size: 20),
                ),
                title: Text(
                  'Help Center & Support',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                subtitle: Text(
                  'Troubleshooting, Contact Form & FAQs',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SupportScreen()),
                  );
                },
              ),
              _buildDivider(isDark),

              // Privacy Policy
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF10B981), size: 20),
                ),
                title: Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                subtitle: Text(
                  'Voice data streaming & Apple/Google compliance',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                  );
                },
              ),
              _buildDivider(isDark),

              // Terms of Service
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7A00).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.article_outlined, color: Color(0xFFFF7A00), size: 20),
                ),
                title: Text(
                  'Terms of Service',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                subtitle: Text(
                  'Culinary safety disclaimer & API usage terms',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
                  );
                },
              ),
              _buildDivider(isDark),

              // Open Source Licenses
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified_outlined, color: Colors.grey, size: 20),
                ),
                title: Text(
                  'Software Licenses',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                subtitle: Text(
                  'LiveKit, Flutter, and third-party attributions',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'CookTalk',
                    applicationVersion: '2.1.0',
                    applicationLegalese: '© 2026 CookTalk Team. All rights reserved.',
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ==================================================================
          // SECTION 5: ACCOUNT ACTIONS
          // ==================================================================
          _buildSectionTitle('Account Actions', isDark: isDark),
          const SizedBox(height: 10),
          _buildCardContainer(
            isDark: isDark,
            children: [
              // Sign Out
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                ),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.redAccent,
                  ),
                ),
                subtitle: Text(
                  'Log out from this device',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.redAccent),
                onTap: _confirmSignOut,
              ),
              _buildDivider(isDark),

              // Delete Account (Red Text - Mandatory for App Stores)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 22),
                ),
                title: const Text(
                  'Delete Account',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.red,
                  ),
                ),
                subtitle: Text(
                  'Permanently erase all personal data & recipes',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.red),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AccountDeletionScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white70 : const Color(0xFF143826),
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildCardContainer({required List<Widget> children, required bool isDark}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161A24) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF263042) : const Color(0xFFECEFE8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? const Color(0xFF263042) : const Color(0xFFECEFE8),
    );
  }
}
