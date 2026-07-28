import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/colors.dart';

/// The three-item bottom tab bar (§1.1): Today, Stock, Orders. Settings is not
/// a fourth tab — it lives as a gear on the Today screen.
///
/// This is the shell for GoRouter's [StatefulShellRoute.indexedStack]: the
/// [navigationShell] is itself an IndexedStack across the three branches, so
/// each tab preserves its scroll position and state (exactly why a tab bar
/// beats a drawer here — the owner bounces between "what's low" and "find this
/// item" constantly).
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onSelect(int index) {
    // `initialLocation: index == currentIndex` re-pops a branch to its root if
    // the owner taps the tab they're already on — the expected tab-bar gesture.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onSelect,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront, color: kn.surface),
            label: 'Today',
          ),
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: kn.surface),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: kn.surface),
            label: 'Orders',
          ),
        ],
      ),
    );
  }
}
