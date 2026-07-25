import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/seed_data.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// 2.5.2 Category picker. Default tags first, then the owner's own, then
/// "Add a new category". Selection is a check glyph AND a bold label (never a
/// colour change), and selecting a row applies and pops immediately.
class CategoryPickerScreen extends ConsumerWidget {
  const CategoryPickerScreen({super.key, this.selected});
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kn = context.kn;
    final tagsAsync = ref.watch(tagsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Category')),
      body: tagsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (tags) {
          final defaults = tags.where(kDefaultTags.contains).toList();
          final custom = tags.where((t) => !kDefaultTags.contains(t)).toList();
          return ListView(
            children: [
              for (final t in defaults) _row(context, t, kn),
              if (custom.isNotEmpty) ...[
                Divider(color: kn.lineHairline, height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      KnSpace.s4, KnSpace.s4, KnSpace.s4, KnSpace.s2),
                  child: Text('YOUR OWN',
                      style: KnType.eyebrow.copyWith(color: kn.textSecondary)),
                ),
                for (final t in custom) _row(context, t, kn),
              ],
              Divider(color: kn.lineHairline, height: 1),
              ListTile(
                minTileHeight: 56,
                leading: Icon(Icons.add, color: kn.textPrimary),
                title: Text('Add a new category',
                    style: KnType.body.copyWith(color: kn.textPrimary)),
                onTap: () => _addCategory(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, String tag, KnColors kn) {
    final isSelected = tag == selected;
    return ListTile(
      minTileHeight: 56,
      title: Text(
        tag,
        style: KnType.body.copyWith(
          color: kn.textPrimary,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check, color: kn.textPrimary) : null,
      onTap: () => Navigator.of(context).pop(tag),
    );
  }

  Future<void> _addCategory(BuildContext context, WidgetRef ref) async {
    final kn = context.kn;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add a new category',
            style: KnType.title3.copyWith(color: kn.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'For example: Drinks, Phone Credit, Party Supplies.',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await addTag(ref, name);
      if (context.mounted) Navigator.of(context).pop(name);
    }
  }
}
