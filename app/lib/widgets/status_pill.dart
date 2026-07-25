import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// The uppercase LOW / ON HOLD / SOLD OUT / REMOVED pill.
///
/// Never colour alone: the word itself carries the meaning, so this reads
/// correctly in greyscale. On dark surfaces the text uses the mandated
/// #FF6E63, never brand red.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.subdued = false});

  final String label;

  /// REMOVED uses the muted colour rather than red.
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final color = subdued ? kn.textSecondary : kn.textRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: KnType.pill.copyWith(color: color),
      ),
    );
  }
}
