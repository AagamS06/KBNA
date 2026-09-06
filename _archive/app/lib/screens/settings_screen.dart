import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/auth_controller.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/pill_button.dart';

/// 2.7 Settings. Opened a handful of times a year, so it lives behind the gear
/// on Today rather than taking a permanent tab slot.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kn = context.kn;
    final settings = ref.watch(liveSettingsProvider);
    final settingsCtl = ref.read(settingsProvider.notifier);
    final removedAsync = ref.watch(removedProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _group('You'),
          _disclosure(context, 'Sign-in details',
              onTap: () => context.push('/settings/account')),
          _switchTile(context, 'Use Face ID to sign in',
              value: settings.faceId, onChanged: settingsCtl.setFaceId),

          _group('Your shop'),
          _disclosure(context, 'Shop details',
              onTap: () => context.push('/settings/shop')),
          _disclosure(context, 'Categories',
              onTap: () => context.push('/settings/categories')),

          _group('Alerts'),
          _switchTile(context, 'Tell me when stock is low',
              value: settings.lowStockAlerts,
              onChanged: settingsCtl.setLowStockAlerts),
          _switchTile(context, 'Tell me about new orders',
              value: settings.newOrderAlerts,
              onChanged: settingsCtl.setNewOrderAlerts),
          _valueTile(
            context,
            'Quiet hours',
            '${settings.quietHoursStart} – ${settings.quietHoursEnd}',
            onTap: () => _editQuietHours(context, ref, settings.quietHoursStart,
                settings.quietHoursEnd),
          ),

          _group('How it looks'),
          _valueTile(context, 'Appearance', _themeLabel(settings.themeMode),
              onTap: () => _pickTheme(context, ref, settings.themeMode)),
          _switchTile(context, 'Bigger buttons',
              value: settings.biggerButtons,
              onChanged: settingsCtl.setBiggerButtons),
          _switchTile(context, 'Buttons on the left',
              value: settings.buttonsOnLeft,
              onChanged: settingsCtl.setButtonsOnLeft),

          _group('Tidying up'),
          _disclosure(
            context,
            'Removed items',
            trailingText:
                removedAsync.maybeWhen(data: (r) => '${r.length}', orElse: () => ''),
            onTap: () => context.push('/settings/removed'),
          ),

          _group('Help'),
          _disclosure(context, 'How this app works',
              onTap: () => _howItWorks(context)),
          _disclosure(context, 'Contact support',
              onTap: () => _contactSupport(context)),

          const SizedBox(height: KnSpace.s6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KnSpace.s4),
            child: PillButton(
              'Sign out',
              variant: PillVariant.secondary,
              onPressed: () => _signOut(context, ref),
            ),
          ),
          const SizedBox(height: KnSpace.s5),
          Center(
            child: Column(
              children: [
                Text('Knightsbridge Newsagency · v1.0 (14)',
                    style: KnType.caption.copyWith(color: kn.textSecondary)),
                Text('Everything is saved on this phone.',
                    style: KnType.caption.copyWith(color: kn.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: KnSpace.s6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KnSpace.s4),
            child: PillButton(
              'Start again with sample stock',
              variant: PillVariant.destructive,
              icon: Icons.warning_amber_rounded,
              onPressed: () => _resetFlow(context, ref),
            ),
          ),
          const SizedBox(height: KnSpace.s8),
        ],
      ),
    );
  }

  // --- row builders -----------------------------------------------------

  Widget _group(String title) => Builder(builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
              KnSpace.s4, KnSpace.s6, KnSpace.s4, KnSpace.s2),
          child: Text(title.toUpperCase(),
              style: KnType.eyebrow.copyWith(color: context.kn.textSecondary)),
        );
      });

  Widget _disclosure(BuildContext context, String label,
      {required VoidCallback onTap, String? trailingText}) {
    final kn = context.kn;
    return ListTile(
      minTileHeight: 56,
      title: Text(label, style: KnType.body.copyWith(color: kn.textPrimary)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null && trailingText.isNotEmpty)
            Text(trailingText,
                style: KnType.body.copyWith(color: kn.textSecondary)),
          const SizedBox(width: KnSpace.s1),
          Icon(Icons.chevron_right, color: kn.textSecondary),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _valueTile(BuildContext context, String label, String value,
      {required VoidCallback onTap}) {
    final kn = context.kn;
    return ListTile(
      minTileHeight: 56,
      title: Text(label, style: KnType.body.copyWith(color: kn.textPrimary)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: KnType.body.copyWith(color: kn.textSecondary)),
          const SizedBox(width: KnSpace.s1),
          Icon(Icons.chevron_right, color: kn.textSecondary),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _switchTile(BuildContext context, String label,
      {required bool value, required ValueChanged<bool> onChanged}) {
    final kn = context.kn;
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: KnSpace.s4),
      title: Text(label, style: KnType.body.copyWith(color: kn.textPrimary)),
      value: value,
      onChanged: onChanged,
    );
  }

  // --- actions ----------------------------------------------------------

  String _themeLabel(ThemeMode m) => switch (m) {
        ThemeMode.system => 'Match phone',
        ThemeMode.light => 'Always light',
        ThemeMode.dark => 'Always dark',
      };

  Future<void> _pickTheme(
      BuildContext context, WidgetRef ref, ThemeMode current) async {
    final chosen = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in ThemeMode.values)
              ListTile(
                minTileHeight: 56,
                title: Text(_themeLabel(m)),
                trailing: m == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, m),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      await ref.read(settingsProvider.notifier).setThemeMode(chosen);
    }
  }

  Future<void> _editQuietHours(BuildContext context, WidgetRef ref,
      String start, String end) async {
    TimeOfDay parse(String s) {
      final parts = s.split(':');
      return TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
    }

    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    final s = await showTimePicker(
        context: context,
        initialTime: parse(start),
        helpText: 'Quiet hours start');
    if (s == null || !context.mounted) return;
    final e = await showTimePicker(
        context: context, initialTime: parse(end), helpText: 'Quiet hours end');
    if (e == null) return;
    await ref.read(settingsProvider.notifier).setQuietHours(fmt(s), fmt(e));
  }

  void _howItWorks(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('How this app works'),
        content: const Text(
          'Everything you change is saved on this phone straight away, even '
          'with no internet. When you\'re back online it goes up to the '
          'website. Tap the minus on a row when you sell something; swipe a '
          'row (or press and hold it) to take an item off the website.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _contactSupport(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text('Contact support'),
        content: Text(
            'Call the person who set this up, or email '
            'owner@knightsbridgenews.com.au.'),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content:
            const Text("You'll need your email and password to get back in."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      // Signing out flips auth state; the router's redirect takes us to the
      // sign-in gate and clears the navigation stack — no manual pop needed.
      ref.read(authProvider.notifier).signOut();
    }
  }

  Future<void> _resetFlow(BuildContext context, WidgetRef ref) async {
    final kn = context.kn;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Start again with sample stock?'),
        content: const Text(
          'This wipes every item, every order and your settings, and puts the '
          'sample stock back. There is no undo.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep my data')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Continue', style: TextStyle(color: kn.textRed)),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;

    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Type ERASE to confirm'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'ERASE'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim() == 'ERASE'),
            child: Text('Erase everything',
                style: TextStyle(color: kn.textRed)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(productsProvider.notifier).resetAll();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sample stock is back.')),
        );
      }
    }
  }
}

/// Read-only display of what appears on the website.
class ShopDetailsScreen extends StatelessWidget {
  const ShopDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    Widget row(String label, String value) => ListTile(
          title: Text(label,
              style: KnType.secondary.copyWith(color: kn.textSecondary)),
          subtitle: Text(value,
              style: KnType.body.copyWith(color: kn.textPrimary)),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Shop details')),
      body: ListView(
        children: [
          row('Name', 'Knightsbridge Newsagency'),
          row('Address',
              'Shop 5, 159 Ridgecrop Drive\nCastle Hill NSW 2154'),
          row('Email', 'owner@knightsbridgenews.com.au'),
        ],
      ),
    );
  }
}

/// A simple category list (rename/reorder/delete is out of scope for this
/// build; the picker's "Add a new category" covers creation).
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kn = context.kn;
    final tagsAsync = ref.watch(tagsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: tagsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (tags) => ListView(
          children: [
            for (final t in tags)
              ListTile(
                minTileHeight: 56,
                title:
                    Text(t, style: KnType.body.copyWith(color: kn.textPrimary)),
              ),
          ],
        ),
      ),
    );
  }
}
