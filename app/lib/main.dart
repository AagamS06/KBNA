import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/auth_controller.dart';
import 'state/providers.dart';
import 'theme/app_theme.dart';
import 'screens/home_shell.dart';
import 'screens/sign_in_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: KnightsbridgeApp()));
}

class KnightsbridgeApp extends ConsumerWidget {
  const KnightsbridgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Best-effort settings for theme mode; defaults until the async load lands.
    final settings = ref.watch(liveSettingsProvider);
    final signedIn = ref.watch(authProvider.select((s) => s.signedIn));

    return MaterialApp(
      title: 'Knightsbridge Newsagency',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: KnTheme.light(),
      darkTheme: KnTheme.dark(),
      home: signedIn ? const HomeShell() : const SignInScreen(),
    );
  }
}
