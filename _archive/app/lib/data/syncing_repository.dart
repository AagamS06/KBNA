import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../models/analytics.dart';
import '../models/app_settings.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../services/notification_service.dart';
import 'local_repository.dart';
import 'outbox.dart';
import 'repository.dart';
import 'supabase_repository.dart';

/// LOCAL-FIRST sync decorator (01-architecture.md §4).
///
/// The rule from §4.3, made literal: **every read and every write hits sqflite
/// first**. There is no "if online, write to the server" branch — that branch
/// is where sync bugs live. A write goes to [local] (which, because it was
/// built with the [Outbox] as its `SyncHooks`, appends an outbox row in the same
/// call), the UI re-renders from local immediately, and only then is the sync
/// worker kicked. The network is a synchroniser, not a dependency: with no
/// signal the app is fully functional and the queue drains later.
///
/// Conflict resolution is the ledger's, not a merge's (§4.4.1): pulled remote
/// movements are UNIONED into the local ledger (deduped by idempotency key) and
/// each touched product's stock is RECOMPUTED from its movements — so the result
/// is independent of the order in which the offline stocktake and the online
/// sale arrive. Product attributes are last-write-wins by `updated_at`, and an
/// unsynced local edit (still in the outbox, hence newer) is never clobbered by
/// a pull.
class SyncingShopRepository implements ShopRepository {
  SyncingShopRepository({
    required this.local,
    required this.remote,
    required this.outbox,
    required this.notifications,
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity();

  final LocalShopRepository local;
  final SupabaseShopRepository remote;
  final Outbox outbox;
  final NotificationService notifications;
  final Connectivity _connectivity;

  bool _online = true;
  bool _syncing = false;
  Timer? _periodic;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  @override
  Future<void> init() async {
    await local.init();
    await remote.init();

    try {
      _online = _isOnline(await _connectivity.checkConnectivity());
      _connSub = _connectivity.onConnectivityChanged.listen((results) {
        final wasOffline = !_online;
        _online = _isOnline(results);
        if (_online && wasOffline) unawaited(sync());
      });
    } catch (_) {
      _online = true; // if connectivity can't be read, assume online and try.
    }

    // Trigger the sync worker on foreground start; the periodic tick backs it up
    // (§4.3 triggers: reconnect, after a mutation, and every 60s foregrounded).
    _periodic = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_online) unawaited(sync());
    });
    unawaited(sync());
  }

  void dispose() {
    _periodic?.cancel();
    unawaited(_connSub?.cancel());
  }

  bool _isOnline(List<ConnectivityResult> r) =>
      r.any((e) => e != ConnectivityResult.none);

  /// Fire-and-forget kick after a local mutation. Never awaited by the UI.
  void _kick() {
    if (_online) unawaited(sync());
  }

  /// Drain the outbox, then pull. Guarded so only one runs at a time.
  Future<void> sync() async {
    if (_syncing || !_online) return;
    _syncing = true;
    try {
      await _drainOutbox();
      await _pull();
    } catch (_) {
      // A failed cycle leaves work queued; the next trigger retries it.
    } finally {
      _syncing = false;
    }
  }

  // --- Push (outbox -> server) -----------------------------------------

  Future<void> _drainOutbox() async {
    final entries = await outbox.pending();
    for (final e in entries) {
      try {
        await _push(e);
        await outbox.markDone(e.id);
      } on PostgrestException catch (err) {
        if (_isTerminal(err)) {
          // A permanent 4xx (e.g. a constraint the client can't satisfy). Keep
          // it, surface it — never silently drop a write (§4.3/§4.5).
          await outbox.markFailed(e.id, err.message);
        } else {
          // Transient (network/5xx/auth). Leave pending and STOP: FIFO order
          // matters, so we must not push a later change ahead of this one.
          await outbox.markRetry(e.id, e.attempts + 1, err.message);
          break;
        }
      } catch (err) {
        await outbox.markRetry(e.id, e.attempts + 1, err.toString());
        break;
      }
    }
  }

  Future<void> _push(OutboxEntry e) async {
    switch (e.operation) {
      case 'upsert_product':
        final p = await local.getProduct(e.entityId);
        if (p != null) await remote.pushProduct(p);
      case 'delete_product':
        await remote.deleteProductForever(e.entityId);
      case 'record_movement':
        final m = await local.movementByKey(e.entityId);
        if (m != null) await remote.pushMovement(m);
      case 'update_order':
        final o = await local.getOrder(e.entityId);
        if (o != null) {
          await remote.pushOrderStatus(o.id, o.status, o.collectedAt);
        }
    }
  }

  /// Terminal = a 4xx that isn't auth/throttle (§4.3). 401/408/429 are transient.
  bool _isTerminal(PostgrestException err) {
    final code = int.tryParse(err.code ?? '');
    if (code == null) return false; // no HTTP code -> treat as transient
    if (code == 401 || code == 408 || code == 429) return false;
    return code >= 400 && code < 500;
  }

  // --- Pull (server -> local) ------------------------------------------

  Future<void> _pull() async {
    final since = await local.getSyncCursor();
    final startedAt = DateTime.now();

    // Products: last-write-wins by updated_at (ingest keeps a newer local edit).
    for (final p in await remote.pullProductsSince(since)) {
      await local.ingestRemoteProduct(p);
    }

    // Movements: union into the ledger, then recompute each touched product.
    final touched = <String>{};
    for (final m in await remote.pullMovementsSince(since)) {
      if (await local.ingestRemoteMovement(m)) touched.add(m.productId);
    }
    for (final id in touched) {
      await local.recomputeStock(id);
    }

    // Orders: upsert, and locally notify on a genuinely new pending reservation.
    for (final o in await remote.pullOrdersSince(since)) {
      final isNew = await local.ingestRemoteOrder(o);
      if (isNew && o.status.isOpen) {
        await notifications.showNewOrder(o);
      }
    }

    // Advance the cursor to when we STARTED (idempotent ingest makes the small
    // overlap harmless and closes the "recorded during the pull" gap).
    await local.setSyncCursor(startedAt);
  }

  // ======================================================================
  // ShopRepository — reads are pure-local; writes go local then kick sync.
  // ======================================================================

  @override
  Future<List<Product>> getProducts() => local.getProducts();
  @override
  Future<List<Product>> getRemovedProducts() => local.getRemovedProducts();
  @override
  Future<Product?> getProduct(String id) => local.getProduct(id);
  @override
  Future<Product?> getProductByBarcode(String barcode) =>
      local.getProductByBarcode(barcode);

  @override
  Future<Product> addProduct(ProductDraft draft) async {
    final p = await local.addProduct(draft);
    _kick();
    return p;
  }

  @override
  Future<Product> updateProduct(
    String id, {
    String? name,
    String? description,
    int? priceCents,
    int? lowStockThreshold,
    String? tag,
    bool? held,
    String? imageUrl,
    bool? clearImageUrl,
    String? imageCredit,
    bool? clearImageCredit,
    String? barcode,
    bool? clearBarcode,
  }) async {
    final p = await local.updateProduct(
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
    _kick();
    return p;
  }

  @override
  Future<void> removeProduct(String id) async {
    await local.removeProduct(id);
    _kick();
  }

  @override
  Future<void> restoreProduct(String id) async {
    await local.restoreProduct(id);
    _kick();
  }

  @override
  Future<void> deleteProductForever(String id) async {
    await local.deleteProductForever(id);
    _kick();
  }

  @override
  Future<Product> duplicateProduct(String id) async {
    final p = await local.duplicateProduct(id);
    _kick();
    return p;
  }

  @override
  Future<Product> adjustStock(String id, int delta, {MovementKind? kind}) async {
    final p = await local.adjustStock(id, delta, kind: kind);
    _kick();
    return p;
  }

  @override
  Future<Product> setCount(String id, int count) async {
    final p = await local.setCount(id, count);
    _kick();
    return p;
  }

  @override
  Future<List<StockMovement>> movementsFor(String productId) =>
      local.movementsFor(productId);

  @override
  Future<Product> setHeld(String id, bool held) async {
    final p = await local.setHeld(id, held);
    _kick();
    return p;
  }

  @override
  Future<List<ShopOrder>> getOrders() => local.getOrders();
  @override
  Future<ShopOrder?> getOrder(String id) => local.getOrder(id);

  @override
  Future<ShopOrder> setOrderStatus(String id, OrderStatus status) async {
    final o = await local.setOrderStatus(id, status);
    _kick();
    return o;
  }

  @override
  Future<List<ProductSalesAggregate>> salesByProduct({
    required DateTime from,
    required DateTime to,
  }) =>
      local.salesByProduct(from: from, to: to);

  @override
  Future<List<DailySalesPoint>> salesByDay({
    required DateTime from,
    required DateTime to,
  }) =>
      local.salesByDay(from: from, to: to);

  // Tags, credentials and settings are device/auth concerns — served locally.
  @override
  Future<List<String>> getTags() => local.getTags();
  @override
  Future<void> addTag(String tag) => local.addTag(tag);
  @override
  Future<Credentials> getCredentials() => local.getCredentials();
  @override
  Future<void> setCredentials(Credentials credentials) =>
      local.setCredentials(credentials);
  @override
  Future<AppSettings> getSettings() => local.getSettings();
  @override
  Future<void> saveSettings(AppSettings settings) =>
      local.saveSettings(settings);

  @override
  Future<void> resetAll() => local.resetAll();
}
