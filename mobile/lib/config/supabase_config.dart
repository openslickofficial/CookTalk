/// Centralized Supabase configuration and OAuth parameters for CookTalk.
class SupabaseConfig {
  /// Supabase project URL (override via --dart-define=SUPABASE_URL=... or edit here)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gvjltmqzcshowcstnetv.supabase.co',
  );

  /// Supabase anon public key (override via --dart-define=SUPABASE_ANON_KEY=... or edit here)
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2amx0bXF6Y3Nob3djc3RuZXR2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg4NTQyODgsImV4cCI6MjEwNDQzMDI4OH0.pHp5run6aw09RxnyZQ88tbO95HoF-PTPxKMRIwiSgHo',
  );

  /// Deep-link redirect URL configured in Supabase Auth Redirect URLs
  static const String authRedirectUrl = 'io.livekit.cooktalk://login-callback/';

  /// Returns true if live Supabase credentials are provided
  static bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  /// Returns a DiceBear critters SVG avatar URL for a given username or initials.
  /// Format: https://api.dicebear.com/10.x/critters/svg?seed={username[0]}
  static String getDiceBearAvatar(String username) {
    final clean = username.trim();
    final seed = clean.isNotEmpty ? clean[0].toUpperCase() : 'U';
    return 'https://api.dicebear.com/10.x/critters/svg?seed=$seed';
  }
}
