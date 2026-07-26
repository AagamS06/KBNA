import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/order.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/common.dart';
import '../widgets/formatting.dart';

/// 2.6.1 Orders list. Grouped by Today / Yesterday / Earlier, newest first.
/// Read-only (reserve-and-collect scope).
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kn = context.kn;
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        titleSpacing: KnSpace.s4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Orders', style: KnType.title2.copyWith(color: kn.textPrimary)),
            ordersAsync.maybeWhen(
              data: (o) => Text('${o.length} online orders',
                  style: KnType.secondary.copyWith(color: kn.textSecondary)),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text("Couldn't load your orders.",
              style: KnType.body.copyWith(color: kn.textPrimary)),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'No online orders yet.\n'
                  "When someone buys from the website, it'll land here.",
            );
          }
          // Build grouped rows.
          final rows = <Widget>[];
          String? lastGroup;
          for (final o in orders) {
            final g = orderGroup(o.createdAt);
            if (g != lastGroup) {
              lastGroup = g;
              rows.add(Padding(
                padding: const EdgeInsets.fromLTRB(
                    KnSpace.s4, KnSpace.s5, KnSpace.s4, KnSpace.s2),
                child: Text(g,
                    style: KnType.eyebrow.copyWith(color: kn.textSecondary)),
              ));
            }
            rows.add(Padding(
              padding: const EdgeInsets.symmetric(horizontal: KnSpace.s4),
              child: _OrderCard(order: o),
            ));
            rows.add(const SizedBox(height: KnSpace.s3));
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: KnSpace.s6),
            children: rows,
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(KnRadius.card),
        onTap: () => context.push('/order/${order.id}'),
        child: Container(
          padding: const EdgeInsets.all(KnSpace.s4),
          decoration: BoxDecoration(
            border: Border.all(color: kn.lineHairline),
            borderRadius: BorderRadius.circular(KnRadius.card),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(relativeTimestamp(order.createdAt),
                        style:
                            KnType.bodyStrong.copyWith(color: kn.textPrimary)),
                    Text(
                      '${order.itemCount} '
                      '${order.itemCount == 1 ? 'item' : 'items'} · '
                      '${order.paymentMethod}',
                      style:
                          KnType.secondary.copyWith(color: kn.textSecondary),
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
      ),
    );
  }
}
