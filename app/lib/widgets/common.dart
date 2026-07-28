import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'pill_button.dart';

/// A red (or muted) uppercase, tracked section label above a heading.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.muted = false});
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Semantics(
      // Decorative — the heading beneath carries the meaning.
      excludeSemantics: true,
      child: Text(
        text.toUpperCase(),
        style: KnType.eyebrow
            .copyWith(color: muted ? kn.textSecondary : kn.textRed),
      ),
    );
  }
}

/// A grouped-list section header (e.g. "AT A GLANCE", "TODAY").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KnSpace.s3),
      child: Eyebrow(text, muted: true),
    );
  }
}

/// The red-bordered "needs attention" card and the black-bordered "all good"
/// card share this shell. Attention uses the red wash + a warning glyph; good
/// uses a hairline black border + a check glyph. Neither relies on colour alone.
class KnCard extends StatelessWidget {
  const KnCard({
    super.key,
    required this.child,
    this.attention = false,
    this.good = false,
    this.padding = const EdgeInsets.all(KnSpace.s4),
  });

  final Widget child;
  final bool attention;
  final bool good;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    Color border;
    Color? fill;
    double width;
    if (attention) {
      border = kn.textRed;
      fill = kn.washRed;
      width = 1.5;
    } else if (good) {
      border = kn.textPrimary;
      fill = null;
      width = 1;
    } else {
      border = kn.lineHairline;
      fill = null;
      width = 1;
    }
    return Container(
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border, width: width),
        borderRadius: BorderRadius.circular(KnRadius.card),
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Label-left / value-right detail row, 56pt tall, with a hairline separator.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    this.value,
    this.trailing,
    this.showDivider = true,
  });

  final String label;
  final String? value;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: KnType.body.copyWith(color: kn.textPrimary)),
              ),
              if (trailing != null)
                trailing!
              else if (value != null)
                Text(value!,
                    style: KnType.bodyStrong.copyWith(color: kn.textPrimary)),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: kn.lineHairline),
      ],
    );
  }
}

/// A centred empty/first-run block: a sentence explaining what would be here,
/// plus the single action that fills it (§2.8 state rules).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.showArrowBadge = false,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showArrowBadge;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: KnSpace.s5, vertical: KnSpace.s10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: kn.textSecondary),
            const SizedBox(height: KnSpace.s4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: KnType.body.copyWith(color: kn.textSecondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: KnSpace.s6),
              PillButton(
                actionLabel!,
                onPressed: onAction,
                showArrowBadge: showArrowBadge,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The quiet, persistent "sync line" at the bottom of the Today scroll. In this
/// local-only build the steady state is "Everything is saved."
class SyncLine extends StatelessWidget {
  const SyncLine({super.key, this.text = 'Everything is saved.'});
  final String text;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(text, style: KnType.caption.copyWith(color: kn.textSecondary)),
          const SizedBox(width: KnSpace.s1),
          Icon(Icons.check, size: 14, color: kn.textSecondary),
        ],
      ),
    );
  }
}
