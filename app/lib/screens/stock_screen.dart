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
import '../widgets/stock_row.dart';

enum StockSort { attention, alpha, price, stockLevel, recent }

extension on StockSort {
  String get label => switch (this) {
        StockSort.attention => 'Needs attention first',
        StockSort.alpha => 'A–Z',
        StockSort.price => 'Price',
        StockSort.stockLevel => 'Stock level',
        StockSort.recent => 'Recently changed',
      };
}

/// 2.3 Stock list. The screen the owner lives in. The search field is
/// deliberately BOTTOM-ANCHORED (§2.3) — it is the most-used control and it
/// must sit in the thumb zone while a customer's paper is in the other hand.
class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  String _tagFilter = 'All';
  StockSort _sort = StockSort.attention;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool _matches(Product p, String q) {
    if (q.isEmpty) return true;
    final needle = q.toLowerCase();
    bool hit(String s) {
      final hay = s.toLowerCase();
      if (hay.contains(needle)) return true;
      // word-start match, so "tel" finds "...Telegraph"
      return hay.split(RegExp(r'\s+')).any((w) => w.startsWith(needle));
    }

    return hit(p.name) || hit(p.tag) || hit(p.description);
  }

  List<Product> _apply(List<Product> all) {
    var list = all
        .where((p) => _tagFilter == 'All' || p.tag == _tagFilter)
        .where((p) => _matches(p, _query))
        .toList();
    switch (_sort) {
      case StockSort.attention:
        break; // repository already returns attention-first, then A–Z
      case StockSort.alpha:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case StockSort.price:
        list.sort((a, b) => a.priceCents.compareTo(b.priceCents));
      case StockSort.stockLevel:
        list.sort((a, b) => a.stock.compareTo(b.stock));
      case StockSort.recent:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return list;
  }

  void _snack(String message, {VoidCallback? onUndo}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        action: onUndo == null
            ? null
            : SnackBarAction(label: 'Undo', onPressed: onUndo),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final settings = ref.watch(liveSettingsProvider);
    final productsAsync = ref.watch(productsProvider);
    final tagsAsync = ref.watch(tagsProvider);
    final controller = ref.read(productsProvider.notifier);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  KnSpace.s4, KnSpace.s4, KnSpace.s4, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text('Stock',
                              style: KnType.display
                                  .copyWith(color: kn.textPrimary)),
                        ),
                        productsAsync.maybeWhen(
                          data: (p) => Text('${p.length} items',
                              style: KnType.secondary
                                  .copyWith(color: kn.textSecondary)),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add item',
                    onPressed: () => _openAdd(context),
                  ),
                ],
              ),
            ),

            // Category chip rail.
            tagsAsync.maybeWhen(
              data: (tags) => _ChipRail(
                tags: ['All', ...tags],
                active: _tagFilter,
                onSelect: (t) => setState(() => _tagFilter = t),
              ),
              orElse: () => const SizedBox(height: KnSpace.s6),
            ),

            // The list.
            Expanded(
              child: productsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text("Couldn't open your stock.",
                      style: KnType.body.copyWith(color: kn.textPrimary)),
                ),
                data: (all) {
                  if (all.isEmpty) {
                    return EmptyState(
                      icon: Icons.inventory_2_outlined,
                      message: 'Nothing in your stock list yet.',
                      actionLabel: 'Add your first item',
                      showArrowBadge: true,
                      onAction: () => _openAdd(context),
                    );
                  }
                  final list = _apply(all);
                  if (list.isEmpty) {
                    return _noResults();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        KnSpace.s4, KnSpace.s2, KnSpace.s4, KnSpace.s4),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: KnSpace.s3),
                    itemBuilder: (context, i) {
                      final p = list[i];
                      return StockRow(
                        product: p,
                        stepperSize: settings.targetSize,
                        buttonsOnLeft: settings.buttonsOnLeft,
                        onTap: () => context.push('/item/${p.id}'),
                        onIncrement: () {
                          controller.adjustStock(p.id, 1);
                          _snack('Added one ${p.name}.',
                              onUndo: () => controller.adjustStock(p.id, -1));
                        },
                        onDecrement: () {
                          controller.adjustStock(p.id, -1);
                          _snack('Sold one ${p.name}.',
                              onUndo: () => controller.adjustStock(p.id, 1));
                        },
                        onCountLongPress: () async {
                          final v = await showNumberPad(context,
                              title: p.name, initial: p.stock);
                          if (v != null) controller.setCount(p.id, v);
                        },
                        onToggleHold: () {
                          final nowHeld = !p.held;
                          controller.setHeld(p.id, nowHeld);
                          _snack(
                            nowHeld
                                ? 'Taken off the website.'
                                : 'Put back on the website.',
                            onUndo: () => controller.setHeld(p.id, !nowHeld),
                          );
                        },
                        onEdit: () => context.push('/item/${p.id}/edit'),
                        onDuplicate: () async {
                          final dup = await controller.duplicate(p.id);
                          _snack('${dup.name} added.');
                        },
                        onRemove: () => _confirmRemove(context, p, controller),
                      );
                    },
                  );
                },
              ),
            ),

            // Bottom-anchored search field (§2.3).
            _SearchBar(
              controller: _search,
              focusNode: _searchFocus,
              onChanged: (v) => setState(() => _query = v),
              onClear: () {
                _search.clear();
                setState(() => _query = '');
              },
              sort: _sort,
              onSort: () => _pickSort(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noResults() {
    if (_query.isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        message: 'Nothing matches "$_query".\n'
            'Check the spelling, or add it as a new item.',
        actionLabel: 'Add "$_query" as a new item',
        onAction: () => _openAdd(context, prefillName: _query),
      );
    }
    return EmptyState(
      icon: Icons.filter_alt_off_outlined,
      message: 'No items tagged $_tagFilter.',
      actionLabel: 'Show all items',
      onAction: () => setState(() => _tagFilter = 'All'),
    );
  }

  void _openAdd(BuildContext context, {String? prefillName}) {
    final q = (prefillName == null || prefillName.isEmpty)
        ? ''
        : '?name=${Uri.encodeQueryComponent(prefillName)}';
    context.push('/add-item$q');
  }

  Future<void> _confirmRemove(
      BuildContext context, Product p, ProductsController controller) async {
    final kn = context.kn;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove ${p.name}?',
            style: KnType.title3.copyWith(color: kn.textPrimary)),
        content: Text(
          'It comes off the website and out of your list. You can put it back '
          'from Settings → Removed items.',
          style: KnType.body.copyWith(color: kn.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove', style: TextStyle(color: kn.textRed)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await controller.remove(p.id);
      _snack('${p.name} removed.',
          onUndo: () => controller.restore(p.id));
    }
  }

  Future<void> _pickSort(BuildContext context) async {
    final kn = context.kn;
    final chosen = await showModalBottomSheet<StockSort>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in StockSort.values)
              ListTile(
                minTileHeight: 56,
                title: Text(s.label,
                    style: KnType.body.copyWith(color: kn.textPrimary)),
                trailing: s == _sort ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, s),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) setState(() => _sort = chosen);
  }
}

class _ChipRail extends StatelessWidget {
  const _ChipRail(
      {required this.tags, required this.active, required this.onSelect});
  final List<String> tags;
  final String active;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: KnSpace.s4, vertical: KnSpace.s2),
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: KnSpace.s2),
        itemBuilder: (context, i) {
          final tag = tags[i];
          final selected = tag == active;
          return Semantics(
            button: true,
            selected: selected,
            label: tag,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onSelect(tag),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: KnSpace.s4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? kn.fillRed : Colors.transparent,
                  border: Border.all(
                      color: selected ? kn.fillRed : kn.lineControl),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      Icon(Icons.check, size: 16, color: kn.onFill),
                      const SizedBox(width: KnSpace.s1),
                    ],
                    Text(
                      tag,
                      style: KnType.label.copyWith(
                        color: selected ? kn.onFill : kn.textPrimary,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.sort,
    required this.onSort,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final StockSort sort;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          KnSpace.s4, KnSpace.s2, KnSpace.s4, KnSpace.s3),
      decoration: BoxDecoration(
        color: kn.surface,
        border: Border(top: BorderSide(color: kn.lineHairline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: KnType.body.copyWith(color: kn.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search stock',
                  hintStyle:
                      KnType.body.copyWith(color: kn.textSecondary),
                  prefixIcon: Icon(Icons.search, color: kn.textSecondary),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.cancel),
                          tooltip: 'Clear the search',
                          onPressed: onClear,
                        ),
                  constraints: const BoxConstraints(minHeight: 56),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: KnSpace.s3),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KnRadius.pill),
                    borderSide: BorderSide(color: kn.lineControl, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KnRadius.pill),
                    borderSide: BorderSide(color: kn.textPrimary, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: KnSpace.s2),
            IconButton(
              icon: const Icon(Icons.swap_vert),
              tooltip: 'Change the order: ${sort.label}',
              onPressed: onSort,
            ),
          ],
        ),
      ),
    );
  }
}
