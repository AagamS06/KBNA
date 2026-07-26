import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/router.dart';
import 'config/backend_config.dart';
import 'state/providers.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase is initialised ONLY when a backend was passed via --dart-define.
  // With no env set this is skipped entirely and the app runs fully on the
  // local sqflite repository — `flutter run` works exactly as before, offline.
  if (BackendConfig.isConfigured) {
    await Supabase.initialize(
      url: BackendConfig.supabaseUrl,
      anonKey: BackendConfig.supabaseAnonKey,
    );
  }

  runApp(const ProviderScope(child: KnightsbridgeApp()));
}

class KnightsbridgeApp extends ConsumerWidget {
  const KnightsbridgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Best-effort settings for theme mode; defaults until the async load lands.
    final settings = ref.watch(liveSettingsProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Knightsbridge Newsagency',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: KnTheme.light(),
      darkTheme: KnTheme.dark(),
      routerConfig: router,
    );
  }
}
