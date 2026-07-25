import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart';
import '../models/product.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/common.dart';
import '../widgets/formatting.dart';
import '../widgets/pill_button.dart';
import 'item_detail_screen.dart';

/// 2.6.2 Order detail. Line items, payment, reference, and — critically — the
/// auto-hold notice that EXPLAINS why items were taken off the website (the
/// website did this silently; the app tells the owner why).
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kn = context.kn;
    final orderAsync = ref.watch(orderByIdProvider(orderId));
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Share this order',
            onPressed: () => orderAsync.whenData((o) {
              if (o != null) _share(context, o);
            }),
          ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (order) {
          if (order == null) {
            return const EmptyState(
              icon: Icons.help_outline,
              message: "This order can't be found.",
            );
          }

          // Which of this order's line items are currently held (auto-hold)?
          final products = productsAsync.value ?? const <Product>[];
          final heldFromThisOrder = order.items
              .where((i) => products.any((p) => p.id == i.productId && p.held))
              .toList();

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(KnSpace.s4),
                  children: [
                    const Eyebrow('Online order'),
                    const SizedBox(height: KnSpace.s2),
                    Semantics(
                      header: true,
                      child: Text(longDateTime(order.createdAt),
                          style:
                              KnType.title1.copyWith(color: kn.textPrimary)),
                    ),
                    const SizedBox(height: KnSpace.s5),
                    KnCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < order.items.length; i++) ...[
                            _LineItem(item: order.items[i]),
                            Divider(height: 1, color: kn.lineHairline),
                          ],
                          Padding(
                            padding: const EdgeInsets.all(KnSpace.s4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total',
                                    style: KnType.title2
                                        .copyWith(color: kn.textPrimary)),
                                Text(money(order.totalCents),
                                    style: KnType.title2
                                        .copyWith(color: kn.textPrimary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: KnSpace.s5),
                    DetailRow(label: 'Paid with', value: order.paymentMethod),
                    GestureDetector(
                      onLongPress: () {
                        Clipboard.setData(
                            ClipboardData(text: order.reference));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Reference copied.')),
                        );
                      },
                      child: DetailRow(
                        label: 'Reference',
                        value: order.reference,
                        showDivider: false,
                      ),
                    ),
                    if (heldFromThisOrder.isNotEmpty) ...[
                      const SizedBox(height: KnSpace.s5),
                      _AutoHoldNotice(
                        count: heldFromThisOrder.length,
                        onSeeThem: () {
                          // Open the first held item's detail.
                          final id = heldFromThisOrder.first.productId;
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) =>
                                  ItemDetailScreen(productId: id)));
                        },
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: kn.surface,
                  border: Border(top: BorderSide(color: kn.lineHairline)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(KnSpace.s4),
                    child: PillButton(
                      'Share this order',
                      variant: PillVariant.secondary,
                      icon: Icons.ios_share,
                      onPressed: () => _share(context, order),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _share(BuildContext context, ShopOrder order) {
    final buffer = StringBuffer()
      ..writeln('Knightsbridge Newsagency — online order')
      ..writeln(order.reference)
      ..writeln(longDateTime(order.createdAt))
      ..writeln('');
    for (final i in order.items) {
      buffer.writeln('${i.qty} × ${i.nameAtTime} — ${money(i.lineTotalCents)}');
    }
    buffer
      ..writeln('')
      ..writeln('Total ${money(order.totalCents)}')
      ..writeln('Paid with ${order.paymentMethod}');

    // Real build: system share sheet (share_plus). Here we show the payload.
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(KnSpace.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share this order',
                style: KnType.title3.copyWith(color: context.kn.textPrimary)),
            const SizedBox(height: KnSpace.s3),
            SelectableText(buffer.toString(),
                style: KnType.body.copyWith(color: context.kn.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem({required this.item});
  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Padding(
      padding: const EdgeInsets.all(KnSpace.s4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nameAtTime,
                    style: KnType.bodyStrong.copyWith(color: kn.textPrimary)),
                Text('${item.qty} × ${money(item.priceCents)}',
                    style:
                        KnType.secondary.copyWith(color: kn.textSecondary)),
              ],
            ),
          ),
          Text(money(item.lineTotalCents),
              style: KnType.numberM.copyWith(color: kn.textPrimary)),
        ],
      ),
    );
  }
}

class _AutoHoldNotice extends StatelessWidget {
  const _AutoHoldNotice({required this.count, required this.onSeeThem});
  final int count;
  final VoidCallback onSeeThem;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return KnCard(
      attention: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: kn.textRed, size: 20),
              const SizedBox(width: KnSpace.s2),
              Expanded(
                child: Text(
                  'This order took $count '
                  '${count == 1 ? 'item' : 'items'} below their alert level, '
                  'so we put them on hold for you.',
                  style: KnType.body.copyWith(color: kn.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: KnSpace.s3),
          Align(
            alignment: Alignment.centerRight,
            child: PillButton(
              count == 1 ? 'See it' : 'See those $count',
              variant: PillVariant.secondary,
              fullWidth: false,
              minHeight: 48,
              onPressed: onSeeThem,
            ),
          ),
        ],
      ),
    );
  }
}
