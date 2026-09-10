class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String avatarUrl;
  final List<String> favoriteCuisines;
  final String cookingFrequency;
  final bool onboardingCompleted;
  final List<String> allergies;
  final List<String> favorites;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.avatarUrl,
    this.favoriteCuisines = const [],
    this.cookingFrequency = 'A few times a week',
    this.onboardingCompleted = false,
    this.allergies = const [],
    this.favorites = const [],
  });

  UserProfile copyWith({
    String? fullName,
    String? avatarUrl,
    List<String>? favoriteCuisines,
    String? cookingFrequency,
    bool? onboardingCompleted,
    List<String>? allergies,
    List<String>? favorites,
  }) {
    return UserProfile(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      favoriteCuisines: favoriteCuisines ?? this.favoriteCuisines,
      cookingFrequency: cookingFrequency ?? this.cookingFrequency,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      allergies: allergies ?? this.allergies,
      favorites: favorites ?? this.favorites,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? 'Samantha',
      avatarUrl: () {
        final raw = json['avatar_url'] as String?;
        if (raw != null && raw.isNotEmpty && !raw.contains('photo-1534528741775-53994a69daeb')) {
          return raw;
        }
        final name = json['full_name'] as String? ?? 'Samantha';
        final seed = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
        return 'https://api.dicebear.com/10.x/critters/svg?seed=$seed';
      }(),
      favoriteCuisines: (json['favorite_cuisines'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      cookingFrequency:
          json['cooking_frequency'] as String? ?? 'A few times a week',
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      allergies: (json['allergies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      favorites: (json['favorites'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'favorite_cuisines': favoriteCuisines,
        'cooking_frequency': cookingFrequency,
        'onboarding_completed': onboardingCompleted,
        'allergies': allergies,
        'favorites': favorites,
      };
}
