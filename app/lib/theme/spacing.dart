/// The 4pt spacing scale from 02-ux-screens.md §5.3. Only these values are
/// legal in the app; using an arbitrary number is a design-system violation.
class KnSpace {
  const KnSpace._();

  static const double s1 = 4; // glyph-to-label
  static const double s2 = 8; // inside a pill, between stacked labels
  static const double s3 = 12; // label to its field
  static const double s4 = 16; // DEFAULT: screen gutter, card + row padding
  static const double s5 = 20; // between cards
  static const double s6 = 24; // between form fields
  static const double s7 = 32; // between form sections
  static const double s8 = 40; // above a section eyebrow
  static const double s9 = 56; // top of a screen's first content block
  static const double s10 = 72; // empty-state vertical padding
}

/// Corner radii (§5.3 "Radii").
class KnRadius {
  const KnRadius._();

  static const double card = 20;
  static const double control = 12;
  static const double sheet = 28;
  static const double pill = 999;
}

/// Touch-target floor. 48 normally; the "Bigger buttons" accessibility setting
/// raises it to 56 (§2.7, §6.1). Widgets read the live value from settings.
class KnTargets {
  const KnTargets._();

  static const double normal = 48;
  static const double bigger = 56;
  static const double numberPadKey = 64;
}
