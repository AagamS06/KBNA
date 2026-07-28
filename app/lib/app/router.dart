import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/add_edit_item_screen.dart';
import '../screens/category_picker_screen.dart';
import '../screens/home_shell.dart';
import '../screens/item_detail_screen.dart';
import '../screens/order_detail_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/removed_items_screen.dart';
import '../screens/scan_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/sign_in_details_screen.dart';
import '../screens/sign_in_screen.dart';
import '../screens/stock_screen.dart';
import '../screens/today_screen.dart';
import '../state/auth_controller.dart';

/// Route path constants. Every screen is reachable by a real URL, so links are
/// deep-linkable (a push notification's `knightsbridge://order/<id>` maps
/// straight onto [order], for instance).
abstract final class Routes {
  static const signIn = '/sign-in';
  static const today = '/';
  static const stock = '/stock';
  static const orders = '/orders';
  static const addItem = '/add-item';
  static const scan = '/scan';
  static const settings = '/settings';
  static const account = '/settings/account';
  static const shopDetails = '/settings/shop';
  static const categories = '/settings/categories';
  static const removed = '/settings/removed';
  static const category = '/category';

  static String item(String id) => '/item/$id';
  static String itemEdit(String id) => '/item/$id/edit';
  static String order(String id) => '/order/$id';
}

/// Bridges Riverpod auth state to GoRouter's [GoRouter.refreshListenable]. When
/// the owner signs in or out, this notifies the router so [_redirect] re-runs.
class _AuthRouterNotifier extends ChangeNotifier {
  _AuthRouterNotifier(this._ref) {
    _ref.listen<bool>(
      authProvider.select((s) => s.signedIn),
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;

  bool get signedIn => _ref.read(authProvider).signedIn;
}

/// The single app router. Overriding [repositoryProvider] etc. never touches
/// this; the router only cares about auth.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = _AuthRouterNotifier(ref);
  ref.onDispose(auth.dispose);

  return GoRouter(
    initialLocation: Routes.today,
    refreshListenable: auth,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      final signedIn = auth.signedIn;
      final atGate = state.matchedLocation == Routes.signIn;
      // Not signed in: force the gate (no redirect loop — the gate returns null).
      if (!signedIn) return atGate ? null : Routes.signIn;
      // Signed in but sitting on the gate: send to Today.
      if (atGate) return Routes.today;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),

      // The three-tab shell. Each tab keeps its own navigation state and scroll
      // position via indexedStack (what the old manual IndexedStack did).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.today,
              builder: (context, state) => const TodayScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.stock,
              builder: (context, state) => const StockScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.orders,
              builder: (context, state) => const OrdersScreen(),
            ),
          ]),
        ],
      ),

      // Full-screen routes that cover the tab bar. They are kept FLAT (not
      // nested) so an imperative `context.push('/item/x/edit')` targets exactly
      // one page — matching the old one-MaterialPageRoute-per-screen behaviour —
      // while each still has its own deep-linkable URL. go_router matches the
      // most specific path, so `/item/:id/edit` wins over `/item/:id`.
      GoRoute(
        path: Routes.addItem,
        builder: (context, state) => AddEditItemScreen(
          prefillName: state.uri.queryParameters['name'],
          prefillBarcode: state.uri.queryParameters['barcode'],
        ),
      ),
      // The barcode scanner. A flat, full-screen route (like /add-item) so it
      // covers the tab bar. It POPS a String — the scanned/typed code — or null.
      GoRoute(
        path: Routes.scan,
        builder: (context, state) => const ScanScreen(),
      ),
      GoRoute(
        path: '/item/:id/edit',
        builder: (context, state) => AddEditItemScreen(
          editProductId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/item/:id',
        builder: (context, state) =>
            ItemDetailScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/order/:id',
        builder: (context, state) =>
            OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.category,
        builder: (context, state) => CategoryPickerScreen(
          selected: state.uri.queryParameters['selected'],
        ),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.account,
        builder: (context, state) => const SignInDetailsScreen(),
      ),
      GoRoute(
        path: Routes.shopDetails,
        builder: (context, state) => const ShopDetailsScreen(),
      ),
      GoRoute(
        path: Routes.categories,
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: Routes.removed,
        builder: (context, state) => const RemovedItemsScreen(),
      ),
    ],
  );
});
