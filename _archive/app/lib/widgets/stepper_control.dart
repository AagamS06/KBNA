import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// The − / value / + stepper used on stock rows, item detail, and the form.
///
/// Two circular targets flank a tabular count. `−` is disabled (and announced
/// as such) at 0. A light haptic tick fires on each press. Long-pressing the
/// count opens the number pad (via [onCountLongPress]) for bulk changes.
class StepperControl extends StatelessWidget {
  const StepperControl({
    super.key,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    this.onCountLongPress,
    this.size = 48,
    this.semanticName,
  });

  final int value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback? onCountLongPress;
  final double size;

  /// e.g. the item name, used to build "Add one to National Geographic".
  final String? semanticName;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final canDecrement = value > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundButton(
          icon: Icons.remove,
          size: size,
          enabled: canDecrement,
          borderColor: kn.lineControl,
          iconColor: kn.textPrimary,
          semanticLabel: semanticName == null
              ? 'Remove one'
              : 'Remove one from $semanticName',
          onTap: () {
            HapticFeedback.selectionClick();
            onDecrement();
          },
        ),
        const SizedBox(width: 8),
        Semantics(
          label: 'On the shelf',
          value: '$value',
          child: GestureDetector(
            onLongPress: onCountLongPress,
            child: Container(
              constraints: BoxConstraints(minWidth: size * 0.9),
              alignment: Alignment.center,
              child: Text(
                '$value',
                style: KnType.numberM.copyWith(color: kn.textPrimary),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _RoundButton(
          icon: Icons.add,
          size: size,
          enabled: true,
          borderColor: kn.lineControl,
          iconColor: kn.textPrimary,
          semanticLabel: semanticName == null
              ? 'Add one'
              : 'Add one to $semanticName',
          onTap: () {
            HapticFeedback.selectionClick();
            onIncrement();
          },
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.size,
    required this.enabled,
    required this.borderColor,
    required this.iconColor,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final bool enabled;
  final Color borderColor;
  final Color iconColor;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: Colors.transparent,
          shape: CircleBorder(side: BorderSide(color: borderColor, width: 1.5)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, size: 22, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
