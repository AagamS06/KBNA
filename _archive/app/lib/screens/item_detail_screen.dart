import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/product.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/common.dart';
import '../widgets/formatting.dart';
import '../widgets/number_pad_sheet.dart';
import '../widgets/photo_block.dart';
import '../widgets/pill_button.dart';
import '../widgets/status_pill.dart';
import '../widgets/stepper_control.dart';

/// 2.4 Item detail. The full picture of one item and the launch point for
/// editing. Read-mostly — the things done in a hurry are already possible from
/// the list. Works for both active and removed (archived) products.
class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kn = context.kn;
    final async = ref.watch(productByIdProvider(productId));
    final controller = ref.read(productsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          async.maybeWhen(
            data: (p) => p == null || !p.active
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.more_horiz),
                    tooltip: 'More actions',
                    onPressed: () => _menu(context, ref, p),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text("Couldn't open this item.",
              style: KnType.body.copyWith(color: kn.textPrimary)),
        ),
        data: (p) {
          if (p == null) {
            return _GoneState();
          }
          final removed = !p.active;
          return Column(
            children: [
              Expanded(
                child: Opacity(
                  opacity: removed ? 0.7 : 1,
                  child: ListView(
                    padding: const EdgeInsets.all(KnSpace.s4),
                    children: [
                      if (removed) ...[
                        _RemovedBanner(),
                        const SizedBox(height: KnSpace.s4),
                      ],
                      PhotoBlock(
                        product: p,
                        borderRadius: BorderRadius.circular(KnRadius.card),
                      ),
                      if (p.imageCredit != null) ...[
                        const SizedBox(height: KnSpace.s2),
                        Text('Photo credit on file · licence applies',
                            style: KnType.caption
                                .copyWith(color: kn.textSecondary)),
                      ],
                      const SizedBox(height: KnSpace.s5),
                      Eyebrow(p.tag),
                      const SizedBox(height: KnSpace.s2),
                      Semantics(
                        header: true,
                        child: Text(p.name,
                            style: KnType.title1
                                .copyWith(color: kn.textPrimary)),
                      ),
                      if (p.description.isNotEmpty) ...[
                        const SizedBox(height: KnSpace.s2),
                        Text(p.description,
                            style: KnType.body.copyWith(color: kn.textPrimary)),
                      ],
                      const SizedBox(height: KnSpace.s5),

                      if (p.held || p.isLow || p.isSoldOut)
                        _StatusCard(product: p, controller: controller),

                      const SizedBox(height: KnSpace.s4),
                      DetailRow(label: 'Price', value: money(p.priceCents)),
                      DetailRow(
                        label: 'On the shelf',
                        trailing: StepperControl(
                          value: p.stock,
                          semanticName: p.name,
                          onDecrement: () =>
                              controller.adjustStock(p.id, -1),
                          onIncrement: () => controller.adjustStock(p.id, 1),
                          onCountLongPress: () async {
                            final v = await showNumberPad(context,
                                title: p.name, initial: p.stock);
                            if (v != null) controller.setCount(p.id, v);
                          },
                        ),
                      ),
                      DetailRow(
                          label: 'Warn me at',
                          value: '${p.lowStockThreshold}'),
                      DetailRow(
                          label: 'On the website',
                          value: p.held ? 'No' : 'Yes'),
                      if (p.barcode != null)
                        DetailRow(label: 'Barcode', value: p.barcode!),
                      DetailRow(
                        label: 'Last changed',
                        value: relativeTimestamp(p.updatedAt),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
              ),
              _Footer(
                child: removed
                    ? PillButton(
                        'Put this item back',
                        onPressed: () async {
                          await controller.restore(p.id);
                          if (context.mounted) context.pop();
                        },
                      )
                    : PillButton(
                        'Edit this item',
                        variant: PillVariant.secondary,
                        onPressed: () => context.push('/item/${p.id}/edit'),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref, Product p) async {
    final kn = context.kn;
    final controller = ref.read(productsProvider.notifier);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              minTileHeight: 56,
              leading: Icon(
                  p.held ? Icons.visibility : Icons.visibility_off),
              title: Text(p.held
                  ? 'Put back on the website'
                  : 'Take off the website'),
              onTap: () => Navigator.pop(context, 'hold'),
            ),
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Duplicate'),
              onTap: () => Navigator.pop(context, 'duplicate'),
            ),
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share item details'),
              onTap: () => Navigator.pop(context, 'share'),
            ),
            ListTile(
              minTileHeight: 56,
              leading: Icon(Icons.delete_outline, color: kn.textRed),
              title:
                  Text('Remove item', style: TextStyle(color: kn.textRed)),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'hold':
        controller.setHeld(p.id, !p.held);
      case 'duplicate':
        await controller.duplicate(p.id);
      case 'share':
        _share(context, p);
      case 'remove':
        await controller.remove(p.id);
        if (context.mounted) context.pop();
    }
  }

  void _share(BuildContext context, Product p) {
    // The real build sends a plain-text receipt through the system share sheet
    // (share_plus / UIActivityViewController). In this dependency-free demo we
    // surface the exact payload so the seam is obvious.
    final text = '${p.name}\n${p.tag} · ${money(p.priceCents)}\n'
        '${p.stock} on the shelf\n${p.description}';
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(KnSpace.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share item details',
                style: KnType.title3.copyWith(color: context.kn.textPrimary)),
            const SizedBox(height: KnSpace.s3),
            SelectableText(text,
                style: KnType.body.copyWith(color: context.kn.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.product, required this.controller});
  final Product product;
  final ProductsController controller;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final String title;
    final String body;
    if (product.held) {
      title = 'ON HOLD — hidden from customers';
      body = 'Stock fell to its alert level, so we took it off the website '
          'for you.';
    } else if (product.isSoldOut) {
      title = 'SOLD OUT';
      body = "There's none on the shelf. It still shows on the website unless "
          'you take it off.';
    } else {
      title = 'LOW';
      body = "It's at or below your alert level.";
    }

    return KnCard(
      attention: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: kn.textRed, size: 20),
              const SizedBox(width: KnSpace.s2),
              Expanded(
                child: Text(title,
                    style: KnType.label.copyWith(color: kn.textRed)),
              ),
            ],
          ),
          const SizedBox(height: KnSpace.s2),
          Text(body, style: KnType.body.copyWith(color: kn.textPrimary)),
          if (product.held) ...[
            const SizedBox(height: KnSpace.s3),
            Align(
              alignment: Alignment.centerRight,
              child: PillButton(
                'Put it back',
                variant: PillVariant.secondary,
                fullWidth: false,
                minHeight: 48,
                onPressed: () => controller.setHeld(product.id, false),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RemovedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KnSpace.s3),
      decoration: BoxDecoration(
        border: Border.all(color: kn.textSecondary),
        borderRadius: BorderRadius.circular(KnRadius.control),
      ),
      child: Row(
        children: [
          const StatusPill('REMOVED', subdued: true),
          const SizedBox(width: KnSpace.s2),
          Expanded(
            child: Text('This item is in your removed archive.',
                style: KnType.secondary.copyWith(color: kn.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _GoneState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.help_outline,
      message: 'This item has been removed.',
      actionLabel: 'Back to stock',
      onAction: () => context.pop(),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Container(
      decoration: BoxDecoration(
        color: kn.surface,
        border: Border(top: BorderSide(color: kn.lineHairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(KnSpace.s4),
          child: child,
        ),
      ),
    );
  }
}
