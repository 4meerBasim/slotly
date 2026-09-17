/// Supplied at build time:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...
/// Keys live outside the repo so the project can be pushed publicly.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
