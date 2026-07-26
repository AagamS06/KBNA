/// Backend selection, read from `--dart-define` at build time (NO secrets in
/// the repo — 01-architecture.md §2.3 ships the anon key, which is safe because
/// RLS enforces access, but even that is passed in, never committed).
///
/// Run local-only (exactly as today, no backend needed):
/// ```
/// flutter run
/// ```
/// Run against Supabase:
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=<publishable anon key>
/// ```
///
/// [isConfigured] is the single switch the rest of the app reads. When false,
/// `main()` skips `Supabase.initialize` and `repositoryProvider` returns a bare
/// [LocalShopRepository] — the app runs fully offline with no Supabase package
/// initialised at all.
class BackendConfig {
  const BackendConfig._();

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// A human label for the current flavour, surfaced in diagnostics/about.
  static const String flavor =
      String.fromEnvironment('APP_FLAVOR', defaultValue: 'dev');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
