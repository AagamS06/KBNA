import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/common.dart';
import '../widgets/formatting.dart';
import 'item_detail_screen.dart';

/// Settings → Removed items. The `active: false` archive — what makes "Remove"
/// safe. Each row can be restored or permanently deleted.
class RemovedItemsScreen extends ConsumerWidget {
  const RemovedItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kn = context.kn;
    final async = ref.watch(removedProductsProvider);
    final controller = ref.read(productsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Removed items')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.delete_outline,
              message: "Nothing's been removed.\n"
                  'Items you remove from your stock list wait here so you can '
                  'put them back.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(KnSpace.s4),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: KnSpace.s3),
            itemBuilder: (context, i) {
              final p = items[i];
              return Container(
                padding: const EdgeInsets.all(KnSpace.s4),
                decoration: BoxDecoration(
                  border: Border.all(color: kn.lineHairline),
                  borderRadius: BorderRadius.circular(KnRadius.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              ItemDetailScreen(productId: p.id))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: KnType.bodyStrong
                                  .copyWith(color: kn.textPrimary)),
                          Text('${p.tag} · ${money(p.priceCents)}',
                              style: KnType.secondary
                                  .copyWith(color: kn.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: KnSpace.s3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.restore_from_trash),
                          label: const Text('Put it back'),
                          onPressed: () => controller.restore(p.id),
                        ),
                        const SizedBox(width: KnSpace.s2),
                        TextButton.icon(
                          icon: Icon(Icons.delete_forever, color: kn.textRed),
                          label: Text('Delete for good',
                              style: TextStyle(color: kn.textRed)),
                          onPressed: () =>
                              _confirmDelete(context, p, controller),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, Product p, ProductsController controller) async {
    final kn = context.kn;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${p.name} for good?',
            style: KnType.title3.copyWith(color: kn.textPrimary)),
        content: Text("This one can't be undone.",
            style: KnType.body.copyWith(color: kn.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete for good', style: TextStyle(color: kn.textRed)),
          ),
        ],
      ),
    );
    if (ok == true) await controller.deleteForever(p.id);
  }
}
