import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/colors.dart';
import 'orders_screen.dart';
import 'stock_screen.dart';
import 'today_screen.dart';

/// The three-item bottom tab bar (§1.1): Today, Stock, Orders. Settings is not
/// a fourth tab — it lives as a gear on the Today screen.
///
/// An [IndexedStack] preserves each tab's scroll position and state, which is
/// exactly why a tab bar beats a drawer here (the owner bounces between "what's
/// low" and "find this item" constantly).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  // Default to Stock (index 1) mid-shift would be ideal per the "sticky tab"
  // rule; on cold start we open on Today, which is the shift-start view.
  int _index = 0;

  static const _tabs = [TodayScreen(), StockScreen(), OrdersScreen()];

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
