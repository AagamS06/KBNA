import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/analytics.dart';
import '../models/app_settings.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import 'database.dart';
import 'repository.dart';
import 'seed_data.dart';
import 'sync_hooks.dart';

/// Local-first implementation of [ShopRepository] backed by sqflite.
///
/// Stock is treated exactly as 01-architecture.md prescribes: an append-only
/// [StockMovement] ledger, with each product's `stock_cached` DERIVED by
/// [_recalc] and never written to directly by feature code. [_recalc] also
/// applies the auto-hold rule from §2.8 (hide at/below the alert level;
/// auto-release once restocked above it), preserving a manual hold.
class LocalShopRepository implements ShopRepository {
  /// [syncHooks] and [ledgerObserver] are BOTH optional and default to null.
  /// With both null this class behaves exactly as it always has — the only
  /// configuration used when no Supabase backend is set. The syncing decorator
  /// passes a [syncHooks] (to fill the outbox) and the app passes a
  /// [ledgerObserver] (to raise local low-stock notifications).
  LocalShopRepository({SyncHooks? syncHooks, LedgerObserver? ledgerObserver})
      : _syncHooks = syncHooks,
        _ledgerObserver = ledgerObserver;

  final SyncHooks? _syncHooks;
  final LedgerObserver? _ledgerObserver;

  static const _uuid = Uuid();
  late Database _db;

  static const _defaultEmail = 'owner@knightsbridgenews.com.au';
  static const _defaultPassword = 'changeMe1234';

  @override
  Future<void> init() async {
    _db = await AppDatabase.instance();
    final count = Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM products'),
        ) ??
        0;
    if (count == 0) {
      await _seed();
    }
  }

  // ======================================================================
  // Products
  // ======================================================================

  @override
  Future<List<Product>> getProducts() async {
    final rows = await _db.query('products', where: 'active = 1');
    final products = rows.map(Product.fromRow).toList();
    products.sort(_attentionThenAlpha);
    return products;
  }

  @override
  Future<List<Product>> getRemovedProducts() async {
    final rows = await _db.query('products',
        where: 'active = 0', orderBy: 'updated_at DESC');
    return rows.map(Product.fromRow).toList();
  }

  @override
  Future<Product?> getProduct(String id) async {
    final rows =
        await _db.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Product.fromRow(rows.first);
  }

  @override
  Future<Product> addProduct(ProductDraft draft) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.insert('products', {
      'id': id,
      'legacy_id': null,
      'name': draft.name,
      'description': draft.description,
      'price_cents': draft.priceCents,
      'low_stock_threshold': draft.lowStockThreshold,
      'tag': draft.tag,
      'active': 1,
      'held': draft.held ? 1 : 0,
      'image_url': draft.imageUrl,
      'image_credit': draft.imageCredit,
      'barcode': draft.barcode,
      'stock_cached': 0,
      'updated_at': now.toIso8601String(),
    });
    await _syncHooks?.onProductChanged(id);
    await _recordMovement(
      productId: id,
      kind: MovementKind.count,
      countedTo: draft.initialStock,
      occurredAt: now,
      source: MovementSource.app,
    );
    // A brand-new item's opening count is not a "crossing" worth alerting on.
    return _recalc(id, notify: false);
  }

  @override
  Future<Product?> getProductByBarcode(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return null;
    final rows = await _db.query('products',
        where: 'barcode = ?', whereArgs: [trimmed], limit: 1);
    if (rows.isEmpty) return null;
    return Product.fromRow(rows.first);
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
    final patch = <String, Object?>{'updated_at': DateTime.now().toIso8601String()};
    if (name != null) patch['name'] = name;
    if (description != null) patch['description'] = description;
    if (priceCents != null) patch['price_cents'] = priceCents;
    if (lowStockThreshold != null) patch['low_stock_threshold'] = lowStockThreshold;
    if (tag != null) patch['tag'] = tag;
    if (held != null) patch['held'] = held ? 1 : 0;
    if (clearImageUrl == true) {
      patch['image_url'] = null;
    } else if (imageUrl != null) {
      patch['image_url'] = imageUrl;
    }
    if (clearImageCredit == true) {
      patch['image_credit'] = null;
    } else if (imageCredit != null) {
      patch['image_credit'] = imageCredit;
    }
    if (clearBarcode == true) {
      patch['barcode'] = null;
    } else if (barcode != null) {
      patch['barcode'] = barcode;
    }

    await _db.update('products', patch, where: 'id = ?', whereArgs: [id]);
    await _syncHooks?.onProductChanged(id);
    // If the threshold changed, the low/held state may need recomputing.
    if (lowStockThreshold != null) return _recalc(id);
    return (await getProduct(id))!;
  }

  @override
  Future<void> removeProduct(String id) async {
    await _db.update(
      'products',
      {'active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _syncHooks?.onProductChanged(id);
  }

  @override
  Future<void> restoreProduct(String id) async {
    await _db.update(
      'products',
      {'active': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _syncHooks?.onProductChanged(id);
  }

  @override
  Future<void> deleteProductForever(String id) async {
    // Guard: only ever hard-delete an already-removed row.
    await _db.delete('products', where: 'id = ? AND active = 0', whereArgs: [id]);
    await _syncHooks?.onProductDeleted(id);
  }

  @override
  Future<Product> duplicateProduct(String id) async {
    final source = await getProduct(id);
    if (source == null) throw StateError('Product $id not found');
    return addProduct(ProductDraft(
      name: '${source.name} (copy)',
      description: source.description,
      priceCents: source.priceCents,
      initialStock: 0,
      lowStockThreshold: source.lowStockThreshold,
      tag: source.tag,
      held: source.held,
      imageUrl: source.imageUrl,
      imageCredit: source.imageCredit,
      barcode: null, // a barcode is unique to one physical product line
    ));
  }

  // ======================================================================
  // Stock (ledger)
  // ======================================================================

  @override
  Future<Product> adjustStock(String id, int delta, {MovementKind? kind}) async {
    if (delta == 0) return (await getProduct(id))!;
    // Choose a sensible kind from the sign when the caller doesn't specify one.
    final resolved =
        kind ?? (delta < 0 ? MovementKind.sale : MovementKind.delivery);
    await _recordMovement(
      productId: id,
      kind: resolved,
      delta: delta,
      occurredAt: DateTime.now(),
      source: MovementSource.app,
    );
    return _recalc(id);
  }

  @override
  Future<Product> setCount(String id, int count) async {
    await _recordMovement(
      productId: id,
      kind: MovementKind.count,
      countedTo: count < 0 ? 0 : count,
      occurredAt: DateTime.now(),
      source: MovementSource.app,
    );
    return _recalc(id);
  }

  @override
  Future<List<StockMovement>> movementsFor(String productId) async {
    final rows = await _db.query('stock_movements',
        where: 'product_id = ?',
        whereArgs: [productId],
        orderBy: 'occurred_at DESC');
    return rows.map(StockMovement.fromRow).toList();
  }

  // ======================================================================
  // Hold
  // ======================================================================

  @override
  Future<Product> setHeld(String id, bool held) async {
    await _db.update(
      'products',
      {'held': held ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _syncHooks?.onProductChanged(id);
    return (await getProduct(id))!;
  }

  // ======================================================================
  // Orders
  // ======================================================================

  @override
  Future<List<ShopOrder>> getOrders() async {
    final rows = await _db.query('orders', orderBy: 'created_at DESC');
    final orders = <ShopOrder>[];
    for (final r in rows) {
      final items = await _itemsFor(r['id'] as String);
      orders.add(ShopOrder.fromRow(r, items));
    }
    return orders;
  }

  @override
  Future<ShopOrder?> getOrder(String id) async {
    final rows =
        await _db.query('orders', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return ShopOrder.fromRow(rows.first, await _itemsFor(id));
  }

  Future<List<OrderItem>> _itemsFor(String orderId) async {
    final rows = await _db.query('order_items',
        where: 'order_id = ?', whereArgs: [orderId], orderBy: 'id ASC');
    return rows.map(OrderItem.fromRow).toList();
  }

  @override
  Future<ShopOrder> setOrderStatus(String id, OrderStatus status) async {
    await _db.update(
      'orders',
      {
        'status': status.name,
        'collected_at': status == OrderStatus.collected
            ? DateTime.now().toIso8601String()
            : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _syncHooks?.onOrderChanged(id);
    return (await getOrder(id))!;
  }

  // ======================================================================
  // Analytics (aggregates over the ledger)
  // ======================================================================

  @override
  Future<List<ProductSalesAggregate>> salesByProduct({
    required DateTime from,
    required DateTime to,
  }) async {
    // Units come from the ledger (kind='sale', delta negative). Revenue comes
    // from the matching order lines' snapshotted price, so a later price change
    // never rewrites past takings.
    final rows = await _db.rawQuery(
      '''
      SELECT m.product_id AS product_id,
             p.name       AS name,
             SUM(-m.delta) AS units,
             SUM(-m.delta * COALESCE(oi.price_cents, p.price_cents)) AS revenue
      FROM stock_movements m
      JOIN products p ON p.id = m.product_id
      LEFT JOIN order_items oi
             ON oi.order_id = m.order_id AND oi.product_id = m.product_id
      WHERE m.kind = 'sale'
        AND m.occurred_at >= ? AND m.occurred_at < ?
      GROUP BY m.product_id, p.name
      ORDER BY units DESC
      ''',
      [from.toIso8601String(), to.toIso8601String()],
    );
    return rows
        .map((r) => ProductSalesAggregate(
              productId: r['product_id'] as String,
              name: r['name'] as String,
              unitsSold: (r['units'] as int?) ?? 0,
              revenueCents: (r['revenue'] as int?) ?? 0,
            ))
        .toList();
  }

  @override
  Future<List<DailySalesPoint>> salesByDay({
    required DateTime from,
    required DateTime to,
  }) async {
    // Group by the date portion of occurred_at (ISO-8601 sorts lexically, so a
    // substring is a valid day key).
    final rows = await _db.rawQuery(
      '''
      SELECT substr(m.occurred_at, 1, 10) AS day,
             SUM(-m.delta) AS units,
             SUM(-m.delta * COALESCE(oi.price_cents, p.price_cents)) AS revenue
      FROM stock_movements m
      JOIN products p ON p.id = m.product_id
      LEFT JOIN order_items oi
             ON oi.order_id = m.order_id AND oi.product_id = m.product_id
      WHERE m.kind = 'sale'
        AND m.occurred_at >= ? AND m.occurred_at < ?
      GROUP BY day
      ORDER BY day ASC
      ''',
      [from.toIso8601String(), to.toIso8601String()],
    );
    return rows
        .map((r) => DailySalesPoint(
              day: DateTime.parse('${r['day']}T00:00:00'),
              unitsSold: (r['units'] as int?) ?? 0,
              revenueCents: (r['revenue'] as int?) ?? 0,
            ))
        .toList();
  }

  // ======================================================================
  // Sync ingestion (used by SyncingShopRepository when pulling from Supabase).
  // These write straight to the local tables WITHOUT firing sync hooks — pulled
  // data must not re-enqueue itself — and are no-ops in a local-only app.
  // ======================================================================

  /// Upsert a product pulled from the server. Last-write-wins by [updatedAt]
  /// (§4.4.2): a local edit newer than the server's is kept.
  Future<void> ingestRemoteProduct(Product remote) async {
    final local = await getProduct(remote.id);
    if (local != null && local.updatedAt.isAfter(remote.updatedAt)) return;
    await _db.insert('products', remote.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Insert a movement pulled from the server if its idempotency key is new.
  /// Returns true if it was inserted (so the caller knows to recompute).
  Future<bool> ingestRemoteMovement(StockMovement m) async {
    final existing = await _db.query('stock_movements',
        where: 'idempotency_key = ?',
        whereArgs: [m.idempotencyKey],
        limit: 1);
    if (existing.isNotEmpty) return false;
    final row = m.toRow()
      ..['id'] = m.id
      ..['recorded_at'] = DateTime.now().toIso8601String();
    await _db.insert('stock_movements', row,
        conflictAlgorithm: ConflictAlgorithm.ignore);
    return true;
  }

  /// Upsert an order pulled from the server. Returns true if this order id was
  /// not seen locally before (a NEW order — the caller may notify).
  Future<bool> ingestRemoteOrder(ShopOrder order) async {
    final existing = await _db
        .query('orders', where: 'id = ?', whereArgs: [order.id], limit: 1);
    final isNew = existing.isEmpty;
    await _db.insert('orders', order.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _db.delete('order_items',
        where: 'order_id = ?', whereArgs: [order.id]);
    for (final item in order.items) {
      await _db.insert('order_items', item.toRow(order.id));
    }
    return isNew;
  }

  /// Public recompute for the sync layer to call after merging pulled movements
  /// (union-of-movements + recompute, §4.4.1). notify:false — a pulled remote
  /// sale is the server's concern to push about, not the local app's.
  Future<Product> recomputeStock(String id) => _recalc(id, notify: false);

  /// Look up a movement by its idempotency key (the sync worker addresses
  /// queued movements this way — they are append-only).
  Future<StockMovement?> movementByKey(String idempotencyKey) async {
    final rows = await _db.query('stock_movements',
        where: 'idempotency_key = ?', whereArgs: [idempotencyKey], limit: 1);
    if (rows.isEmpty) return null;
    return StockMovement.fromRow(rows.first);
  }

  /// The pull cursor: the latest `recorded_at` we've pulled from the server.
  Future<DateTime?> getSyncCursor() async {
    final v = await _kvGet('sync.cursor');
    return v == null ? null : DateTime.tryParse(v);
  }

  Future<void> setSyncCursor(DateTime at) =>
      _kvSet('sync.cursor', at.toIso8601String());

  // ======================================================================
  // Tags
  // ======================================================================

  @override
  Future<List<String>> getTags() async {
    final rows = await _db.query('tags', orderBy: 'sort_order ASC');
    return rows.map((r) => r['name'] as String).toList();
  }

  @override
  Future<void> addTag(String tag) async {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return;
    final existing = await _db.query('tags',
        where: 'name = ? COLLATE NOCASE', whereArgs: [trimmed], limit: 1);
    if (existing.isNotEmpty) return;
    final maxOrder = Sqflite.firstIntValue(
            await _db.rawQuery('SELECT MAX(sort_order) FROM tags')) ??
        0;
    await _db.insert('tags', {
      'name': trimmed,
      'sort_order': maxOrder + 1,
      'is_default': 0,
    });
  }

  // ======================================================================
  // Credentials + settings
  // ======================================================================

  @override
  Future<Credentials> getCredentials() async {
    final email = await _kvGet('cred.email') ?? _defaultEmail;
    final password = await _kvGet('cred.password') ?? _defaultPassword;
    return Credentials(email: email, password: password);
  }

  @override
  Future<void> setCredentials(Credentials credentials) async {
    await _kvSet('cred.email', credentials.email);
    await _kvSet('cred.password', credentials.password);
  }

  @override
  Future<AppSettings> getSettings() async {
    final raw = await _kvGet('settings');
    if (raw == null) return const AppSettings();
    final m = jsonDecode(raw) as Map<String, Object?>;
    return AppSettings(
      themeMode: ThemeMode.values.byName(
          (m['themeMode'] as String?) ?? ThemeMode.system.name),
      biggerButtons: (m['biggerButtons'] as bool?) ?? false,
      buttonsOnLeft: (m['buttonsOnLeft'] as bool?) ?? false,
      lowStockAlerts: (m['lowStockAlerts'] as bool?) ?? true,
      newOrderAlerts: (m['newOrderAlerts'] as bool?) ?? true,
      faceId: (m['faceId'] as bool?) ?? false,
      quietHoursStart: (m['quietHoursStart'] as String?) ?? '21:00',
      quietHoursEnd: (m['quietHoursEnd'] as String?) ?? '07:00',
    );
  }

  @override
  Future<void> saveSettings(AppSettings s) async {
    await _kvSet(
      'settings',
      jsonEncode({
        'themeMode': s.themeMode.name,
        'biggerButtons': s.biggerButtons,
        'buttonsOnLeft': s.buttonsOnLeft,
        'lowStockAlerts': s.lowStockAlerts,
        'newOrderAlerts': s.newOrderAlerts,
        'faceId': s.faceId,
        'quietHoursStart': s.quietHoursStart,
        'quietHoursEnd': s.quietHoursEnd,
      }),
    );
  }

  Future<String?> _kvGet(String key) async {
    final rows =
        await _db.query('kv', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> _kvSet(String key, String value) async {
    await _db.insert('kv', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ======================================================================
  // Lifecycle
  // ======================================================================

  @override
  Future<void> resetAll() async {
    await _db.delete('order_items');
    await _db.delete('orders');
    await _db.delete('stock_movements');
    await _db.delete('products');
    await _db.delete('tags');
    await _db.delete('kv');
    await _seed();
  }

  // ======================================================================
  // Internals
  // ======================================================================

  Future<void> _recordMovement({
    required String productId,
    required MovementKind kind,
    int? delta,
    int? countedTo,
    required DateTime occurredAt,
    required MovementSource source,
    String? orderId,
    String? note,
  }) async {
    // For the app the client action itself is the idempotency unit. For a web
    // order we key on order + product so a replay can't double-apply (§4.3).
    final idempotencyKey = orderId != null ? '$orderId:$productId' : _uuid.v4();
    await _db.insert('stock_movements', {
      'id': _uuid.v4(),
      'product_id': productId,
      'kind': kind.name,
      'delta': delta,
      'counted_to': countedTo,
      'occurred_at': occurredAt.toIso8601String(),
      'recorded_at': DateTime.now().toIso8601String(),
      'source': _sourceToDb(source),
      'order_id': orderId,
      'note': note,
      'idempotency_key': idempotencyKey,
    });
    // Web-order / system movements are not owner actions to push back up; only
    // app-sourced movements enter the outbox.
    if (source == MovementSource.app) {
      await _syncHooks?.onMovementRecorded(idempotencyKey, productId);
    }
  }

  /// Recompute a product's stock from its ledger and apply the auto-hold rule.
  /// This mirrors recalc_stock() + trg_auto_hold() in 01-architecture.md.
  ///
  /// When [notify] is true and the recompute pushes the item from ABOVE its
  /// alert level to at/below it (a genuine crossing, not merely "is low"), the
  /// [LedgerObserver] is told so a local low-stock notification can fire (§5.1).
  Future<Product> _recalc(String id, {bool notify = true}) async {
    // Baseline: the most recent stocktake.
    final countRows = await _db.query(
      'stock_movements',
      where: 'product_id = ? AND kind = ?',
      whereArgs: [id, MovementKind.count.name],
      orderBy: 'occurred_at DESC',
      limit: 1,
    );

    DateTime baseAt;
    int baseQty;
    if (countRows.isEmpty) {
      baseAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      baseQty = 0;
    } else {
      baseAt = DateTime.parse(countRows.first['occurred_at'] as String);
      baseQty = (countRows.first['counted_to'] as int?) ?? 0;
    }

    // Apply every non-count movement after the baseline.
    final deltaRows = await _db.query(
      'stock_movements',
      columns: ['delta', 'occurred_at', 'kind'],
      where: 'product_id = ? AND kind != ?',
      whereArgs: [id, MovementKind.count.name],
    );
    int sum = 0;
    for (final r in deltaRows) {
      final occurred = DateTime.parse(r['occurred_at'] as String);
      if (occurred.isAfter(baseAt)) {
        sum += (r['delta'] as int?) ?? 0;
      }
    }
    final newStock = (baseQty + sum) < 0 ? 0 : (baseQty + sum);

    // Read current state to apply the auto-hold transition rules.
    final current = (await getProduct(id))!;
    final threshold = current.lowStockThreshold;
    final oldHeld = current.held;
    final oldStock = current.stock;

    bool newHeld = oldHeld;
    if (newStock <= threshold && !oldHeld) {
      newHeld = true; // hide from customers
    } else if (newStock > threshold && oldHeld && oldStock <= threshold) {
      newHeld = false; // auto-release once genuinely restocked
    }

    await _db.update(
      'products',
      {
        'stock_cached': newStock,
        'held': newHeld ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    // Fire a low-stock alert only on the downward crossing of an active item.
    final crossedDown = newStock <= threshold && oldStock > threshold;
    if (notify && crossedDown && current.active) {
      _ledgerObserver?.onLowStockCrossed(id);
    }

    return (await getProduct(id))!;
  }

  String _sourceToDb(MovementSource s) {
    switch (s) {
      case MovementSource.webOrder:
        return 'web_order';
      case MovementSource.system:
        return 'system';
      case MovementSource.app:
        return 'app';
    }
  }

  int _attentionThenAlpha(Product a, Product b) {
    int rank(Product p) {
      if (p.held) return 0;
      if (p.isSoldOut) return 1;
      if (p.isLow) return 2;
      return 3;
    }

    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  Future<void> _seed() async {
    final now = DateTime.now();
    final seededAt = now.subtract(const Duration(days: 30));

    // Tags, in the website's order.
    for (var i = 0; i < kDefaultTags.length; i++) {
      await _db.insert('tags', {
        'name': kDefaultTags[i],
        'sort_order': i,
        'is_default': 1,
      });
    }

    // Products + opening count movements.
    final idByLegacy = <int, String>{};
    for (final s in kSeedProducts) {
      final id = _uuid.v4();
      idByLegacy[s.legacyId] = id;
      await _db.insert('products', {
        'id': id,
        'legacy_id': s.legacyId,
        'name': s.name,
        'description': s.description,
        'price_cents': s.priceCents,
        'low_stock_threshold': s.lowStockThreshold,
        'tag': s.tag,
        'active': 1,
        'held': 0,
        'image_url': null,
        'image_credit': null,
        'barcode': null,
        'stock_cached': 0,
        'updated_at': seededAt.toIso8601String(),
      });
      await _recordMovement(
        productId: id,
        kind: MovementKind.count,
        countedTo: s.stock,
        occurredAt: seededAt,
        source: MovementSource.system,
      );
    }

    // Seed orders, applied as web_order sales so the ledger + auto-hold
    // reproduce the wireframes' "needs attention" state.
    final priceByLegacy = {for (final s in kSeedProducts) s.legacyId: s.priceCents};
    final nameByLegacy = {for (final s in kSeedProducts) s.legacyId: s.name};
    for (final o in kSeedOrders) {
      final orderId = _uuid.v4();
      final occurredAt = now.subtract(Duration(minutes: o.minutesAgo));
      var total = 0;
      for (final line in o.lines) {
        total += (priceByLegacy[line.legacyId] ?? 0) * line.qty;
      }
      await _db.insert('orders', {
        'id': orderId,
        'reference': o.reference,
        'created_at': occurredAt.toIso8601String(),
        'total_cents': total,
        'payment_method': o.paymentMethod,
      });
      for (final line in o.lines) {
        final pid = idByLegacy[line.legacyId]!;
        await _db.insert('order_items', {
          'order_id': orderId,
          'product_id': pid,
          'name_at_time': nameByLegacy[line.legacyId],
          'price_cents': priceByLegacy[line.legacyId],
          'qty': line.qty,
        });
        await _recordMovement(
          productId: pid,
          kind: MovementKind.sale,
          delta: -line.qty,
          occurredAt: occurredAt,
          source: MovementSource.webOrder,
          orderId: orderId,
        );
      }
    }

    // Recalculate every seeded product once so stock_cached + held are correct.
    // notify:false — seeding must not raise a burst of low-stock notifications.
    for (final id in idByLegacy.values) {
      await _recalc(id, notify: false);
    }

    // Default credentials + settings.
    await setCredentials(
        const Credentials(email: _defaultEmail, password: _defaultPassword));
    await saveSettings(const AppSettings());
  }
}
