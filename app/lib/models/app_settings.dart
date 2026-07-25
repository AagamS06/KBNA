import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

/// User-facing preferences (02-ux-screens.md §2.7). Persisted as a small
/// key/value table so adding a setting never needs a schema migration.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.biggerButtons = false,
    this.buttonsOnLeft = false,
    this.lowStockAlerts = true,
    this.newOrderAlerts = true,
    this.faceId = false,
    this.quietHoursStart = '21:00',
    this.quietHoursEnd = '07:00',
  });

  /// "Appearance": Match phone / Always light / Always dark.
  final ThemeMode themeMode;

  /// Raises every touch target from 48 to 56pt (accessibility).
  final bool biggerButtons;

  /// Mirrors row-trailing controls to the leading edge for left-handed thumbs.
  final bool buttonsOnLeft;

  final bool lowStockAlerts;
  final bool newOrderAlerts;
  final bool faceId;
  final String quietHoursStart;
  final String quietHoursEnd;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? biggerButtons,
    bool? buttonsOnLeft,
    bool? lowStockAlerts,
    bool? newOrderAlerts,
    bool? faceId,
    String? quietHoursStart,
    String? quietHoursEnd,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      biggerButtons: biggerButtons ?? this.biggerButtons,
      buttonsOnLeft: buttonsOnLeft ?? this.buttonsOnLeft,
      lowStockAlerts: lowStockAlerts ?? this.lowStockAlerts,
      newOrderAlerts: newOrderAlerts ?? this.newOrderAlerts,
      faceId: faceId ?? this.faceId,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }

  /// Minimum touch-target height honouring the "Bigger buttons" setting.
  double get targetSize => biggerButtons ? 56 : 48;
}

/// The owner's sign-in details. Stored locally for the offline-first demo.
///
/// NOTE: this is a LOCAL DEMO credential store mirroring the website's original
/// plaintext model. In production these move behind Supabase Auth (see
/// 01-architecture.md §3); the repository interface is the seam where that
/// swap happens without touching any screen.
@immutable
class Credentials {
  const Credentials({required this.email, required this.password});
  final String email;
  final String password;
}
