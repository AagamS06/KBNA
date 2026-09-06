import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../config/backend_config.dart';
import '../data/local_repository.dart';
import '../data/outbox.dart';
import '../data/photo_service.dart';
import '../data/repository.dart';
import '../data/supabase_repository.dart';
import '../data/sync_hooks.dart';
import '../data/syncing_repository.dart';
import '../models/analytics.dart';
import '../models/app_settings.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../services/notification_service.dart';

/// The on-device notification service (THE NOTIFICATION SEAM). Local alerts
/// today; FCM/APNs push slots in behind [PushRegistrar] later with no change
/// here. No-op on web/Windows and until permission is granted.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  // Web has no dart:io; fall back to the no-op there. Everywhere else the local
  // implementation self-guards unsupported platforms.
  return LocalNotificationService();
});

/// Bridges a low-stock ledger crossing to a local notification, gated on the
/// owner's "Tell me when stock is low" setting.
class _NotifyingLedgerObserver implements LedgerObserver {
  _NotifyingLedgerObserver(this._ref);
  final Ref _ref;

  @override
  void onLowStockCrossed(String productId) {
    // Fire-and-forget: the recompute path must not await notification work.
    Future(() async {
      final settings = _ref.read(liveSettingsProvider);
      if (!settings.lowStockAlerts) return;
      final product = await _ref.read(repositoryProvider).getProduct(productId);
      if (product == null) return;
      await _ref.read(notificationServiceProvider).showLowStock(product);
    }());
  }
}

/// The single repository instance — THE BACKEND SEAM.
///
/// * No `--dart-define` backend  -> a bare [LocalShopRepository] (exactly as the
///   app has always run: offline, local-only, no Supabase package touched).
/// * Backend configured          -> a [SyncingShopRepository] wrapping the same
///   local store plus a [SupabaseShopRepository], draining an [Outbox].
///
/// Either way it's a [ShopRepository]; no screen or controller can tell which.
final repositoryProvider = Provider<ShopRepository>((ref) {
  final observer = _NotifyingLedgerObserver(ref);

  if (!BackendConfig.isConfigured) {
    return LocalShopRepository(ledgerObserver: observer);
  }

  final outbox = Outbox();
  final local =
      LocalShopRepository(syncHooks: outbox, ledgerObserver: observer);
  final remote = SupabaseShopRepository(Supabase.instance.client);
  final syncing = SyncingShopRepository(
    local: local,
    remote: remote,
    outbox: outbox,
    notifications: ref.read(notificationServiceProvider),
  );
  ref.onDispose(syncing.dispose);
  return syncing;
});

/// The photo seam. Real integration: system pickers (prompt-free) + the
/// downscale/EXIF-strip pipeline + Openverse for "Find one for me". See
/// data/photo_service.dart.
final photoServiceProvider = Provider<PhotoService>((ref) {
  final service = SystemPhotoService();
  ref.onDispose(service.dispose);
  return service;
});

/// Resolves once the local database is open and seeded. Every controller awaits
/// this before its first query, so screens never race the database open.
final repoReadyProvider = FutureProvider<ShopRepository>((ref) async {
  final repo = ref.read(repositoryProvider);
  await repo.init();
  return repo;
});

// ======================================================================
// Settings
// ======================================================================

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final repo = await ref.watch(repoReadyProvider.future);
    return repo.getSettings();
  }

  Future<void> _save(AppSettings next) async {
    final repo = await ref.read(repoReadyProvider.future);
    await repo.saveSettings(next);
    state = AsyncData(next);
  }

  AppSettings get _current => state.value ?? const AppSettings();

  Future<void> setThemeMode(ThemeMode mode) =>
      _save(_current.copyWith(themeMode: mode));
  Future<void> setBiggerButtons(bool v) =>
      _save(_current.copyWith(biggerButtons: v));
  Future<void> setButtonsOnLeft(bool v) =>
      _save(_current.copyWith(buttonsOnLeft: v));
  Future<void> setLowStockAlerts(bool v) =>
      _save(_current.copyWith(lowStockAlerts: v));
  Future<void> setNewOrderAlerts(bool v) =>
      _save(_current.copyWith(newOrderAlerts: v));
  Future<void> setFaceId(bool v) => _save(_current.copyWith(faceId: v));
  Future<void> setQuietHours(String start, String end) =>
      _save(_current.copyWith(quietHoursStart: start, quietHoursEnd: end));
}

final settingsProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// Synchronous best-effort view of settings for theming / layout. Falls back to
/// defaults until the async load completes.
final liveSettingsProvider = Provider<AppSettings>((ref) {
  return ref.watch(settingsProvider).value ?? const AppSettings();
});

// ======================================================================
// Products
// ======================================================================

class ProductsController extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async {
    final repo = await ref.watch(repoReadyProvider.future);
    return repo.getProducts();
  }

  Future<ShopRepository> get _repo => ref.read(repoReadyProvider.future);

  Future<void> _refresh() async {
    final repo = await _repo;
    state = AsyncData(await repo.getProducts());
    _invalidateDerived();
  }

  void _invalidateDerived() {
    ref.invalidate(removedProductsProvider);
    ref.invalidate(productByIdProvider);
  }

  Future<Product> adjustStock(String id, int delta) async {
    final repo = await _repo;
    final p = await repo.adjustStock(id, delta);
    await _refresh();
    return p;
  }

  Future<Product> setCount(String id, int count) async {
    final repo = await _repo;
    final p = await repo.setCount(id, count);
    await _refresh();
    return p;
  }

  Future<Product> setHeld(String id, bool held) async {
    final repo = await _repo;
    final p = await repo.setHeld(id, held);
    await _refresh();
    return p;
  }

  Future<Product> add(ProductDraft draft) async {
    final repo = await _repo;
    final p = await repo.addProduct(draft);
    await _refresh();
    ref.invalidate(tagsProvider);
    return p;
  }

  Future<Product> update(
    String id, {
    String? name,
    String? description,
    int? priceCents,
    int? lowStockThreshold,
    String? tag,
    bool? held,
    String? imageUrl,
    bool clearImageUrl = false,
    String? imageCredit,
    bool clearImageCredit = false,
    String? barcode,
    bool clearBarcode = false,
  }) async {
    final repo = await _repo;
    final p = await repo.updateProduct(
      id,
      name: name,
      description: description,
      priceCents: priceCents,
      lowStockThreshold: lowStockThreshold,
      tag: tag,
      held: held,
      imageUrl: imageUrl,
      clearImageUrl: clearImageUrl,
      imageCredit: imageCredit,
      clearImageCredit: clearImageCredit,
      barcode: barcode,
      clearBarcode: clearBarcode,
    );
    await _refresh();
    return p;
  }

  Future<void> remove(String id) async {
    final repo = await _repo;
    await repo.removeProduct(id);
    await _refresh();
  }

  Future<void> restore(String id) async {
    final repo = await _repo;
    await repo.restoreProduct(id);
    await _refresh();
  }

  Future<void> deleteForever(String id) async {
    final repo = await _repo;
    await repo.deleteProductForever(id);
    await _refresh();
  }

  Future<Product> duplicate(String id) async {
    final repo = await _repo;
    final p = await repo.duplicateProduct(id);
    await _refresh();
    return p;
  }

  Future<void> resetAll() async {
    final repo = await _repo;
    await repo.resetAll();
    await _refresh();
    ref.invalidate(ordersProvider);
    ref.invalidate(tagsProvider);
    ref.invalidate(settingsProvider);
  }
}

final productsProvider =
    AsyncNotifierProvider<ProductsController, List<Product>>(
        ProductsController.new);

/// Removed (archived) products.
final removedProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = await ref.watch(repoReadyProvider.future);
  return repo.getRemovedProducts();
});

/// A single product by id — works for active AND removed rows (item detail).
final productByIdProvider =
    FutureProvider.family<Product?, String>((ref, id) async {
  // Depend on the products list so a stock/hold change refreshes the detail.
  ref.watch(productsProvider);
  final repo = await ref.watch(repoReadyProvider.future);
  return repo.getProduct(id);
});

// ======================================================================
// Orders (read-only)
// ======================================================================

final ordersProvider = FutureProvider<List<ShopOrder>>((ref) async {
  final repo = await ref.watch(repoReadyProvider.future);
  return repo.getOrders();
});

final orderByIdProvider =
    FutureProvider.family<ShopOrder?, String>((ref, id) async {
  final repo = await ref.watch(repoReadyProvider.future);
  return repo.getOrder(id);
});

// ======================================================================
// Tags
// ======================================================================

final tagsProvider = FutureProvider<List<String>>((ref) async {
  final repo = await ref.watch(repoReadyProvider.future);
  return repo.getTags();
});

/// Adds a custom category, then refreshes the tag list. Takes a [WidgetRef] so
/// it can be called straight from a screen's callback.
Future<void> addTag(WidgetRef ref, String tag) async {
  final repo = await ref.read(repoReadyProvider.future);
  await repo.addTag(tag);
  ref.invalidate(tagsProvider);
}

// ======================================================================
// Order lifecycle (pending -> ready -> collected)
// ======================================================================

/// Advances an order's status, then refreshes the orders list and this order's
/// detail. The click-&-collect feature screen calls this; the data path exists
/// now so that screen has nothing to wire but its UI.
Future<ShopOrder> setOrderStatus(
    WidgetRef ref, String id, OrderStatus status) async {
  final repo = await ref.read(repoReadyProvider.future);
  final order = await repo.setOrderStatus(id, status);
  ref.invalidate(ordersProvider);
  ref.invalidate(orderByIdProvider(id));
  return order;
}

// ======================================================================
// Barcode lookup (for the later scanner UI)
// ======================================================================

/// Resolves a scanned barcode to a product (null if unknown). Depends on the
/// products list so a freshly-added barcode is found without a manual refresh.
final productByBarcodeProvider =
    FutureProvider.family<Product?, String>((ref, barcode) async {
  ref.watch(productsProvider);
  final repo = await ref.watch(repoReadyProvider.future);
  return repo.getProductByBarcode(barcode);
});

// ======================================================================
// Analytics (aggregates over the ledger)
// ======================================================================

/// A date window. A record type, so it carries value-equality for free — which
/// is exactly what a `.family` key needs.
typedef DateWindow = ({DateTime from, DateTime to});

final salesByProductProvider =
    FutureProvider.family<List<ProductSalesAggregate>, DateWindow>(
        (ref, window) async {
  ref.watch(productsProvider);
  final repo = await ref.watch(repoReadyProvider.future);
  return repo.salesByProduct(from: window.from, to: window.to);
});

final salesByDayProvider =
    FutureProvider.family<List<DailySalesPoint>, DateWindow>(
        (ref, window) async {
  ref.watch(productsProvider);
  final repo = await ref.watch(repoReadyProvider.future);
  return repo.salesByDay(from: window.from, to: window.to);
});
