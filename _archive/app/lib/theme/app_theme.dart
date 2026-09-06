import 'package:flutter/material.dart';

import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

/// Builds the light and dark [ThemeData]. Material 3, flat (no elevation —
/// the design system expresses hierarchy with hairline borders, not shadow),
/// with the [KnColors] token set attached as a ThemeExtension.
class KnTheme {
  const KnTheme._();

  static ThemeData light() => _build(Brightness.light, KnColors.light);
  static ThemeData dark() => _build(Brightness.dark, KnColors.dark);

  static ThemeData _build(Brightness brightness, KnColors c) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.fillRed,
      onPrimary: c.onFill,
      secondary: c.fillRed,
      onSecondary: c.onFill,
      error: c.textRed,
      onError: c.onFill,
      surface: c.surface,
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.surfaceRaised,
      outline: c.lineControl,
      outlineVariant: c.lineHairline,
    );

    final baseText = TextTheme(
      displayLarge: KnType.display,
      headlineLarge: KnType.title1,
      headlineMedium: KnType.title2,
      titleLarge: KnType.title3,
      titleMedium: KnType.label,
      labelLarge: KnType.button,
      bodyLarge: KnType.body,
      bodyMedium: KnType.secondary,
      bodySmall: KnType.caption,
    ).apply(
      bodyColor: c.textPrimary,
      displayColor: c.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.surface,
      canvasColor: c.surface,
      textTheme: baseText,
      splashFactory: InkRipple.splashFactory,
      extensions: <ThemeExtension<dynamic>>[c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(
        color: c.lineHairline,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.textPrimary,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? c.surface : c.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => KnType.label.copyWith(color: c.textPrimary),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.textPrimary,
        contentTextStyle: KnType.body.copyWith(color: c.surface),
        actionTextColor: c.onFill,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(KnRadius.sheet)),
        ),
      ),
      focusColor: c.focus,
    );
  }
}
