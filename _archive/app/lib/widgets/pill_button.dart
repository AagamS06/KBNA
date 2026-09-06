import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

enum PillVariant { primary, secondary, destructive, text }

/// The app's one button. Sentence case labels on both platforms (a documented
/// deviation — the labels are short sentences). Destructive buttons carry the
/// verb AND a glyph, so state never rests on colour alone.
class PillButton extends StatelessWidget {
  const PillButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.variant = PillVariant.primary,
    this.icon,
    this.showArrowBadge = false,
    this.loading = false,
    this.loadingLabel,
    this.fullWidth = true,
    this.minHeight = 56,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillVariant variant;
  final IconData? icon;

  /// The site's signature CTA: a circular arrow badge on the trailing edge.
  final bool showArrowBadge;

  final bool loading;
  final String? loadingLabel;
  final bool fullWidth;
  final double minHeight;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final enabled = onPressed != null && !loading;

    Color bg;
    Color fg;
    Color? border;
    switch (variant) {
      case PillVariant.primary:
        bg = kn.fillRed;
        fg = kn.onFill;
        border = null;
      case PillVariant.secondary:
        bg = Colors.transparent;
        fg = kn.textPrimary;
        border = kn.textPrimary;
      case PillVariant.destructive:
        bg = Colors.transparent;
        fg = kn.textRed;
        border = kn.textRed;
      case PillVariant.text:
        bg = Colors.transparent;
        fg = kn.textPrimary;
        border = null;
    }

    final effectiveLabel = loading ? (loadingLabel ?? 'Working…') : label;

    Widget content;
    if (loading) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          ),
          const SizedBox(width: KnSpace.s3),
          Text(effectiveLabel, style: KnType.button.copyWith(color: fg)),
        ],
      );
    } else {
      final row = <Widget>[];
      if (icon != null) {
        row.add(Icon(icon, size: 20, color: fg));
        row.add(const SizedBox(width: KnSpace.s2));
      }
      row.add(Flexible(
        child: Text(
          effectiveLabel,
          style: KnType.button.copyWith(color: fg),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ));
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: row,
      );

      if (showArrowBadge) {
        content = Stack(
          alignment: Alignment.center,
          children: [
            content,
            Positioned(
              right: 6,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kn.onFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_forward, size: 20, color: kn.fillRed),
              ),
            ),
          ],
        );
      }
    }

    final button = Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KnRadius.pill),
          side: border == null
              ? BorderSide.none
              : BorderSide(color: border, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Container(
            constraints: BoxConstraints(minHeight: minHeight),
            padding: const EdgeInsets.symmetric(horizontal: KnSpace.s5),
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? effectiveLabel,
      child: fullWidth ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}
