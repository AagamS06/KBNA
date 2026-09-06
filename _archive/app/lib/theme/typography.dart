import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The type scale from 02-ux-screens.md §5.2.
///
/// Two families, chosen deliberately (not decoratively):
///  * Plus Jakarta Sans — headings, UI labels, buttons, and all NUMBERS.
///  * Atkinson Hyperlegible — body copy, descriptions, hints. Drawn by the
///    Braille Institute to disambiguate similar glyphs for low-vision readers,
///    which is exactly what a 55-year-old reading a description at 6am needs.
///
/// Colours are NOT baked into these styles — callers apply the correct
/// brightness-aware token from [KnColors]. Sizes are the fontScale-1.0 values;
/// they scale with the OS text-size setting because we do not disable
/// MediaQuery textScaler anywhere.
class KnType {
  const KnType._();

  // Cached so google_fonts doesn't rebuild the TextStyle on every access.
  static final TextStyle _jakarta = GoogleFonts.plusJakartaSans();
  static final TextStyle _atkinson = GoogleFonts.atkinsonHyperlegible();

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  // --- Headings / UI (Plus Jakarta Sans) --------------------------------
  static TextStyle get display => _jakarta.copyWith(
        fontSize: 34,
        height: 38 / 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.03 * 34,
      );

  static TextStyle get title1 => _jakarta.copyWith(
        fontSize: 28,
        height: 33 / 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.03 * 28,
      );

  static TextStyle get title2 => _jakarta.copyWith(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.025 * 22,
      );

  static TextStyle get title3 => _jakarta.copyWith(
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.015 * 18,
      );

  static TextStyle get eyebrow => _jakarta.copyWith(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.18 * 12,
      );

  static TextStyle get label => _jakarta.copyWith(
        fontSize: 15,
        height: 20 / 15,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get button => _jakarta.copyWith(
        fontSize: 17,
        height: 22 / 17,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get pill => _jakarta.copyWith(
        fontSize: 11,
        height: 14 / 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.12 * 11,
      );

  static TextStyle get numberL => _jakarta.copyWith(
        fontSize: 28,
        height: 32 / 28,
        fontWeight: FontWeight.w800,
        fontFeatures: _tabular,
      );

  static TextStyle get numberM => _jakarta.copyWith(
        fontSize: 20,
        height: 24 / 20,
        fontWeight: FontWeight.w800,
        fontFeatures: _tabular,
      );

  // --- Body (Atkinson Hyperlegible) -------------------------------------
  static TextStyle get body => _atkinson.copyWith(
        fontSize: 17,
        height: 26 / 17,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodyStrong => _atkinson.copyWith(
        fontSize: 17,
        height: 26 / 17,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get secondary => _atkinson.copyWith(
        fontSize: 15,
        height: 22 / 15,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get caption => _atkinson.copyWith(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w400,
      );
}
