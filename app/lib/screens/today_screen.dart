import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/order.dart';
import '../models/product.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/common.dart';
import '../widgets/formatting.dart';
import '../widgets/number_pad_sheet.dart';
import '../widgets/pill_button.dart';

/// 2.2 Today. Answer at a glance: is anything wrong, and what happened while
/// I wasn't looking?
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kn = context.kn;
    final productsAsync = ref.watch(productsProvider);
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(productsProvider);
            ref.invalidate(ordersProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                KnSpace.s4, KnSpace.s4, KnSpace.s4, KnSpace.s8),
            children: [
              // Header: large title + settings gear.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text('Today',
                              style: KnType.display.copyWith(color: kn.textPrimary)),
                        ),
                        Text(longDate(DateTime.now()),
                            style: KnType.secondary
                                .copyWith(color: kn.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    iconSize: 24,
                    tooltip: 'Settings',
                    onPressed: () => context.push('/settings'),
                  ),
                ],
              ),
              const SizedBox(height: KnSpace.s5),

              productsAsync.when(
                loading: () => const _LoadingBlock(),
                error: (e, _) => _ErrorBlock(
                  onRetry: () => ref.invalidate(productsProvider),
                ),
                data: (products) {
                  if (products.isEmpty) {
                    return const _EmptyShop();
                  }
                  return _AttentionAndGlance(products: products);
                },
              ),

              const SizedBox(height: KnSpace.s7),
              const SectionHeader('Recent online orders'),
              ordersAsync.when(
                loading: () => const _LoadingBlock(),
                error: (e, _) => const SizedBox.shrink(),
                data: (orders) {
                  if (orders.isEmpty) {
                    return KnCard(
                      child: Text(
                        "No online orders yet. They'll appear here the moment "
                        'one comes in.',
                        style: KnType.body.copyWith(color: kn.textSecondary),
                      ),
                    );
                  }
                  final recent = orders.take(3).toList();
                  return Column(
                    children: [
                      KnCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < recent.length; i++) ...[
                              _OrderRow(order: recent[i]),
                              if (i != recent.length - 1)
                                Divider(height: 1, color: kn.lineHairline),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: KnSpace.s3),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PillButton(
                          'See all orders',
                          variant: PillVariant.secondary,
                          fullWidth: false,
                          minHeight: 48,
                          // Switch to the Orders tab (keeps the bottom bar).
                          onPressed: () => context.go('/orders'),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: KnSpace.s8),
              const SyncLine(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttentionAndGlance extends ConsumerWidget {
  const _AttentionAndGlance({required this.products});
  final List<Product> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kn = context.kn;
    final attention = products.where((p) => p.needsAttention).toList();
    final inStock = products.length;
    final onWebsite = products.where((p) => !p.held).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attention.isEmpty)
          KnCard(
            good: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check, color: kn.textPrimary),
                const SizedBox(width: KnSpace.s2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('All good', muted: true),
                      const SizedBox(height: KnSpace.s2),
                      Text('Nothing needs your attention.',
                          style: KnType.title3.copyWith(color: kn.textPrimary)),
                      Text('Every item is above its alert level.',
                          style:
                              KnType.body.copyWith(color: kn.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          KnCard(
            attention: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: kn.textRed),
                    const SizedBox(width: KnSpace.s2),
                    Eyebrow('Needs attention'),
                  ],
                ),
                const SizedBox(height: KnSpace.s3),
                Semantics(
                  header: true,
                  child: Text(
                    '${attention.length} '
                    '${attention.length == 1 ? 'item is' : 'items are'} '
                    'low or on hold',
                    style: KnType.title2.copyWith(color: kn.textPrimary),
                  ),
                ),
                const SizedBox(height: KnSpace.s3),
                for (var i = 0; i < attention.length; i++) ...[
                  _AttentionRow(product: attention[i]),
                  if (i != attention.length - 1)
                    Divider(height: KnSpace.s4, color: kn.lineHairline),
                ],
              ],
            ),
          ),
        const SizedBox(height: KnSpace.s7),
        const SectionHeader('At a glance'),
        Row(
          children: [
            Expanded(
                child: _StatTile(number: inStock, label: 'items in\nstock')),
            const SizedBox(width: KnSpace.s4),
            Expanded(
                child:
                    _StatTile(number: onWebsite, label: 'on the\nwebsite')),
          ],
        ),
      ],
    );
  }
}

class _AttentionRow extends ConsumerWidget {
  const _AttentionRow({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kn = context.kn;
    final statusBits = <String>[
      '${product.stock} left',
      'alert at ${product.lowStockThreshold}',
      if (product.held) 'ON HOLD',
    ];

    return InkWell(
      onTap: () => context.push('/item/${product.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KnSpace.s2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: KnType.bodyStrong.copyWith(color: kn.textPrimary)),
                  Text(statusBits.join(' · '),
                      style: KnType.secondary.copyWith(color: kn.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: KnSpace.s2),
            if (product.held)
              PillButton(
                'Release',
                variant: PillVariant.secondary,
                fullWidth: false,
                minHeight: 48,
                onPressed: () =>
                    ref.read(productsProvider.notifier).setHeld(product.id, false),
              )
            else
              PillButton(
                'Restock',
                variant: PillVariant.secondary,
                fullWidth: false,
                minHeight: 48,
                onPressed: () async {
                  final v = await showNumberPad(context,
                      title: product.name, initial: product.stock);
                  if (v != null) {
                    ref.read(productsProvider.notifier).setCount(product.id, v);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends ConsumerWidget {
  const _StatTile({required this.number, required this.label});
  final int number;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kn = context.kn;
    return KnCard(
      child: SizedBox(
        height: 96 - KnSpace.s4 * 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$number',
                style: KnType.numberL.copyWith(color: kn.textPrimary)),
            Text(label,
                style: KnType.caption.copyWith(color: kn.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});
  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return InkWell(
      onTap: () => context.push('/order/${order.id}'),
      child: Padding(
        padding: const EdgeInsets.all(KnSpace.s4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(relativeTimestamp(order.createdAt),
                      style: KnType.bodyStrong.copyWith(color: kn.textPrimary)),
                  Text(
                    '${order.itemCount} '
                    '${order.itemCount == 1 ? 'item' : 'items'} · '
                    '${order.paymentMethod}',
                    style: KnType.secondary.copyWith(color: kn.textSecondary),
                  ),
                ],
              ),
            ),
            Text(money(order.totalCents),
                style: KnType.numberM.copyWith(color: kn.textPrimary)),
            const SizedBox(width: KnSpace.s2),
            Icon(Icons.chevron_right, color: kn.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _EmptyShop extends StatelessWidget {
  const _EmptyShop();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.inventory_2_outlined,
      message: "Your stock list is empty.\n"
          "Add the first thing you sell and it'll show up here.",
      actionLabel: 'Add your first item',
      showArrowBadge: true,
      onAction: () {
        // Adding happens from the Stock tab's + button; nudge the owner there.
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Open the Stock tab and tap + to add your first item.'),
        ));
      },
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: KnSpace.s7),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return KnCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "We couldn't reach your shop's information just now. "
            'Nothing is lost.',
            style: KnType.body.copyWith(color: kn.textPrimary),
          ),
          const SizedBox(height: KnSpace.s3),
          PillButton('Try again',
              variant: PillVariant.secondary,
              fullWidth: false,
              minHeight: 48,
              onPressed: onRetry),
        ],
      ),
    );
  }
}
