/// Supabase project the accounts and saved meetings live in, passed at build time:
///
///     flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=...
///
/// The anon key is public by design (Row Level Security protects the data).
/// Without both values accounts are off and the app works as before.
class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Where Google sign-in and the email link return to on the phone.
  /// Must be listed under Authentication → URL Configuration → Redirect URLs.
  static const mobileRedirect = 'ro.pjr.echo://login-callback';
}
