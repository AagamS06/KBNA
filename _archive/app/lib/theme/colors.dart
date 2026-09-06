import 'package:flutter/material.dart';

/// The Knightsbridge palette, as a Material [ThemeExtension] so every widget
/// can read the exact token it needs for the current brightness via
/// `Theme.of(context).extension<KnColors>()!` (or the `context.kn` helper).
///
/// The palette is three base colours — signal red #E1251B, black #111111,
/// white — and every other value here is a tint/shade that exists for a single
/// documented contrast reason (see 02-ux-screens.md §5.1).
///
/// THE ONE NON-NEGOTIABLE RULE: #E1251B on #111111 is 4.0:1 and FAILS WCAG AA
/// for text. Red *text* on a dark surface is therefore always [textRed]
/// (#FF6E63, 6.9:1). Brand red (#E1251B) on dark is permitted only as a
/// non-text graphic element — a rule, a bar, or a fill behind white text.
@immutable
class KnColors extends ThemeExtension<KnColors> {
  const KnColors({
    required this.surface,
    required this.surfaceRaised,
    required this.textPrimary,
    required this.textSecondary,
    required this.textRed,
    required this.fillRed,
    required this.accentRed,
    required this.lineHairline,
    required this.lineControl,
    required this.washRed,
    required this.focus,
    required this.onFill,
  });

  final Color surface;
  final Color surfaceRaised;
  final Color textPrimary;
  final Color textSecondary;

  /// Red text: eyebrows, error text, destructive labels. Brightness-aware.
  final Color textRed;

  /// Primary button / active chip fill. White-on-this is 5.8:1 on any bg.
  final Color fillRed;

  /// Brand red for NON-TEXT graphics only (rules, the 4pt row status bar, logo).
  final Color accentRed;

  final Color lineHairline;
  final Color lineControl;
  final Color washRed;

  /// System focus ring (keyboard / switch-control only). Not a brand colour.
  final Color focus;

  /// Text/glyph colour that sits on top of [fillRed] — always white.
  final Color onFill;

  static const _brandRed = Color(0xFFE1251B);
  static const _fillRed = Color(0xFFC81A12);
  static const _focus = Color(0xFF2B6CFF);

  static const light = KnColors(
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF6F6F6),
    textPrimary: Color(0xFF111111),
    textSecondary: Color(0xFF5C5C5C),
    textRed: Color(0xFFB3140C),
    fillRed: _fillRed,
    accentRed: _brandRed,
    lineHairline: Color(0xFFE6E6E6),
    lineControl: Color(0xFF8A8A8A),
    washRed: Color(0xFFFDECEB),
    focus: _focus,
    onFill: Color(0xFFFFFFFF),
  );

  static const dark = KnColors(
    surface: Color(0xFF111111),
    surfaceRaised: Color(0xFF1C1C1C),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA8A8A8),
    textRed: Color(0xFFFF6E63),
    fillRed: _fillRed,
    accentRed: _brandRed,
    lineHairline: Color(0x24FFFFFF), // rgba(255,255,255,0.14)
    lineControl: Color(0x8CFFFFFF), // rgba(255,255,255,0.55)
    washRed: Color(0xFF2A1110),
    focus: _focus,
    onFill: Color(0xFFFFFFFF),
  );

  @override
  KnColors copyWith({
    Color? surface,
    Color? surfaceRaised,
    Color? textPrimary,
    Color? textSecondary,
    Color? textRed,
    Color? fillRed,
    Color? accentRed,
    Color? lineHairline,
    Color? lineControl,
    Color? washRed,
    Color? focus,
    Color? onFill,
  }) {
    return KnColors(
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textRed: textRed ?? this.textRed,
      fillRed: fillRed ?? this.fillRed,
      accentRed: accentRed ?? this.accentRed,
      lineHairline: lineHairline ?? this.lineHairline,
      lineControl: lineControl ?? this.lineControl,
      washRed: washRed ?? this.washRed,
      focus: focus ?? this.focus,
      onFill: onFill ?? this.onFill,
    );
  }

  @override
  KnColors lerp(ThemeExtension<KnColors>? other, double t) {
    if (other is! KnColors) return this;
    return KnColors(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textRed: Color.lerp(textRed, other.textRed, t)!,
      fillRed: Color.lerp(fillRed, other.fillRed, t)!,
      accentRed: Color.lerp(accentRed, other.accentRed, t)!,
      lineHairline: Color.lerp(lineHairline, other.lineHairline, t)!,
      lineControl: Color.lerp(lineControl, other.lineControl, t)!,
      washRed: Color.lerp(washRed, other.washRed, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      onFill: Color.lerp(onFill, other.onFill, t)!,
    );
  }
}

/// Convenience access: `context.kn.textRed`.
extension KnColorsContext on BuildContext {
  KnColors get kn => Theme.of(this).extension<KnColors>()!;
}
