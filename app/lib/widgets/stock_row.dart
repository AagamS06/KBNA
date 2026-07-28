import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'formatting.dart';
import 'status_pill.dart';
import 'stepper_control.dart';

/// One row in the Stock list. The whole row (except the stepper) opens Item
/// detail; the stepper adjusts stock in place. A 4pt red leading rule marks
/// low/held/sold-out state, always paired with the status word.
///
/// Gestures:
///  * swipe right  -> take off / put back on the website (no confirmation)
///  * swipe left   -> reveals Edit / Remove via the actions menu
///  * long press   -> the context menu (the taught path on Android)
///  * long-press the count -> the number pad
///
/// The entire row is one accessibility node with custom actions, so a screen
/// reader user has the same power as the swipe gestures (§6.3).
class StockRow extends StatelessWidget {
  const StockRow({
    super.key,
    required this.product,
    required this.onTap,
    required this.onDecrement,
    required this.onIncrement,
    required this.onCountLongPress,
    required this.onToggleHold,
    required this.onEdit,
    required this.onDuplicate,
    required this.onRemove,
    this.stepperSize = 48,
    this.buttonsOnLeft = false,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onCountLongPress;
  final VoidCallback onToggleHold;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;
  final double stepperSize;
  final bool buttonsOnLeft;

  bool get _flagged => product.held || product.isLow || product.isSoldOut;

  String? get _statusWord {
    if (product.held) return 'ON HOLD';
    if (product.isSoldOut) return 'SOLD OUT';
    if (product.isLow) return 'LOW';
    return null;
  }

  Future<void> _openMenu(BuildContext context) async {
    final kn = context.kn;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuTile(
              icon: product.held ? Icons.visibility : Icons.visibility_off,
              label: product.held
                  ? 'Put back on the website'
                  : 'Take off the website',
              onTap: () => Navigator.pop(context, 'hold'),
            ),
            _MenuTile(
                icon: Icons.edit_outlined,
                label: 'Edit',
                onTap: () => Navigator.pop(context, 'edit')),
            _MenuTile(
                icon: Icons.copy_outlined,
                label: 'Duplicate',
                onTap: () => Navigator.pop(context, 'duplicate')),
            _MenuTile(
                icon: Icons.pin_outlined,
                label: 'Set the count',
                onTap: () => Navigator.pop(context, 'count')),
            _MenuTile(
              icon: Icons.delete_outline,
              label: 'Remove item',
              destructive: true,
              color: kn.textRed,
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          ],
        ),
      ),
    );
    switch (choice) {
      case 'hold':
        onToggleHold();
      case 'edit':
        onEdit();
      case 'duplicate':
        onDuplicate();
      case 'count':
        onCountLongPress();
      case 'remove':
        onRemove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;

    // Accessibility value string: everything the row conveys, in words.
    final valueParts = <String>[
      money(product.priceCents),
      '${product.stock} on the shelf',
      if (product.isSoldOut) 'sold out' else if (product.isLow) 'low stock',
      if (product.held) 'on hold, hidden from customers',
    ];

    final stepper = StepperControl(
      value: product.stock,
      size: stepperSize,
      semanticName: product.name,
      onDecrement: onDecrement,
      onIncrement: onIncrement,
      onCountLongPress: onCountLongPress,
    );

    final priceAndStepper = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: buttonsOnLeft
          ? [
              stepper,
              Text(money(product.priceCents),
                  style: KnType.numberM.copyWith(color: kn.textPrimary)),
            ]
          : [
              Text(money(product.priceCents),
                  style: KnType.numberM.copyWith(color: kn.textPrimary)),
              stepper,
            ],
    );

    final categoryLine = product.held
        ? '${product.tag} · hidden from customers'
        : product.tag;

    final rowContent = Container(
      constraints: const BoxConstraints(minHeight: 88),
      decoration: BoxDecoration(
        border: Border.all(color: kn.lineHairline),
        borderRadius: BorderRadius.circular(KnRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 4pt leading status rule (non-text brand red graphic).
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: _flagged ? kn.accentRed : Colors.transparent,
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(KnRadius.card)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  KnSpace.s3, KnSpace.s3, KnSpace.s4, KnSpace.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: KnType.bodyStrong.copyWith(color: kn.textPrimary),
                        ),
                      ),
                      if (_statusWord != null) ...[
                        const SizedBox(width: KnSpace.s2),
                        StatusPill(_statusWord!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(categoryLine,
                      style: KnType.secondary.copyWith(color: kn.textSecondary)),
                  const SizedBox(height: KnSpace.s2),
                  priceAndStepper,
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      button: true,
      label: '${product.name}, ${product.tag}',
      value: valueParts.join(', '),
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        const CustomSemanticsAction(label: 'Add one'): onIncrement,
        if (product.stock > 0)
          const CustomSemanticsAction(label: 'Remove one'): onDecrement,
        CustomSemanticsAction(
            label: product.held
                ? 'Put back on the website'
                : 'Take off the website'): onToggleHold,
        const CustomSemanticsAction(label: 'Set the count'): onCountLongPress,
        const CustomSemanticsAction(label: 'Edit'): onEdit,
        const CustomSemanticsAction(label: 'Remove item'): onRemove,
      },
      child: Dismissible(
        key: ValueKey('row_${product.id}'),
        // Swipes trigger an action then snap back (confirmDismiss returns false).
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            onToggleHold();
          } else {
            await _openMenu(context);
          }
          return false;
        },
        background: _SwipeBg(
          alignment: Alignment.centerLeft,
          color: kn.fillRed,
          textColor: kn.onFill,
          label: product.held ? 'Put back' : 'Take off',
          icon: product.held ? Icons.visibility : Icons.visibility_off,
        ),
        secondaryBackground: _SwipeBg(
          alignment: Alignment.centerRight,
          color: kn.surfaceRaised,
          textColor: kn.textPrimary,
          label: 'Edit · Remove',
          icon: Icons.more_horiz,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(KnRadius.card),
            onTap: onTap,
            onLongPress: () => _openMenu(context),
            child: rowContent,
          ),
        ),
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  const _SwipeBg({
    required this.alignment,
    required this.color,
    required this.textColor,
    required this.label,
    required this.icon,
  });

  final Alignment alignment;
  final Color color;
  final Color textColor;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: KnSpace.s5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(KnRadius.card),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: KnSpace.s2),
          Text(label, style: KnType.button.copyWith(color: textColor)),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final c = color ?? kn.textPrimary;
    return ListTile(
      minTileHeight: 56,
      leading: Icon(icon, color: c),
      title: Text(label, style: KnType.body.copyWith(color: c)),
      onTap: onTap,
    );
  }
}
