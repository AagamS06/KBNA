import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_repository.dart';
import '../data/photo_service.dart';
import '../data/repository.dart';
import '../models/app_settings.dart';
import '../models/order.dart';
import '../models/product.dart';

/// The single repository instance. This is the backend seam: to add Supabase
/// sync later, override this provider with a syncing implementation and nothing
/// else in the app changes.
final repositoryProvider = Provider<ShopRepository>((ref) {
  return LocalShopRepository();
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
