import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/analytics.dart';
import '../models/app_settings.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import 'repository.dart';
import 'seed_data.dart';

/// Supabase implementation of [ShopRepository] (01-architecture.md §2).
///
/// It talks to the same tables the SQL schema in `supabase/schema.sql` defines:
/// `products` (with the DB trigger deriving `stock_cached` and applying the
/// auto-hold), the append-only `stock_movements` ledger, and read-only
/// `orders` / `order_items`.
///
/// It is a first-class citizen — the SAME interface as [LocalShopRepository] —
/// so it can be used on its own. In practice the app wraps it in
/// [SyncingShopRepository] and it is driven through the raw push/pull methods at
/// the bottom of this file, never awaited on the UI's critical path.
///
/// Device-local concerns (owner credentials, per-phone [AppSettings], and the
/// destructive `resetAll`) intentionally throw [UnsupportedError]: auth is
/// Supabase Auth, settings live on the device, and the app must never wipe the
/// shared server. The syncing decorator serves all three from local storage, so
/// these are never reached in normal use.
class SupabaseShopRepository implements ShopRepository {
  SupabaseShopRepository(this._client);

  final SupabaseClient _client;
  static const _uuid = Uuid();

  @override
  Future<void> init() async {/* Supabase.initialize() runs in main(). */}

  // ======================================================================
  // Products
  // ======================================================================

  @override
  Future<List<Product>> getProducts() async {
    final rows = await _client.from('products').select().eq('active', true);
    final products = rows.map(_productFromRemote).toList()
      ..sort(_attentionThenAlpha);
    return products;
  }

  @override
  Future<List<Product>> getRemovedProducts() async {
    final rows = await _client
        .from('products')
        .select()
        .eq('active', false)
        .order('updated_at', ascending: false);
    return rows.map(_productFromRemote).toList();
  }

  @override
  Future<Product?> getProduct(String id) async {
    final rows =
        await _client.from('products').select().eq('id', id).limit(1);
    if (rows.isEmpty) return null;
    return _productFromRemote(rows.first);
  }

  @override
  Future<Product?> getProductByBarcode(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return null;
    final rows =
        await _client.from('products').select().eq('barcode', trimmed).limit(1);
    if (rows.isEmpty) return null;
    return _productFromRemote(rows.first);
  }

  @override
  Future<Product> addProduct(ProductDraft draft) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _client.from('products').insert({
      'id': id,
      'name': draft.name,
      'description': draft.description,
      'price_cents': draft.priceCents,
      'low_stock_threshold': draft.lowStockThreshold,
      'tag': draft.tag,
      'active': true,
      'held': draft.held,
      'image_url': draft.imageUrl,
      'image_credit': draft.imageCredit,
      'barcode': draft.barcode,
      'updated_at': now.toIso8601String(),
    });
    await pushMovement(StockMovement(
      id: _uuid.v4(),
      productId: id,
      kind: MovementKind.count,
      countedTo: draft.initialStock,
      occurredAt: now,
      source: MovementSource.app,
      idempotencyKey: _uuid.v4(),
    ));
    return (await getProduct(id))!;
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
    if (held != null) patch['held'] = held;
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
    await _client.from('products').update(patch).eq('id', id);
    return (await getProduct(id))!;
  }

  @override
  Future<void> removeProduct(String id) async {
    await _client.from('products').update(
        {'active': false, 'updated_at': DateTime.now().toIso8601String()}).eq(
        'id', id);
  }

  @override
  Future<void> restoreProduct(String id) async {
    await _client.from('products').update(
        {'active': true, 'updated_at': DateTime.now().toIso8601String()}).eq(
        'id', id);
  }

  @override
  Future<void> deleteProductForever(String id) async {
    await _client.from('products').delete().eq('id', id).eq('active', false);
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
      barcode: null,
    ));
  }

  // ======================================================================
  // Stock (ledger)
  // ======================================================================

  @override
  Future<Product> adjustStock(String id, int delta, {MovementKind? kind}) async {
    if (delta == 0) return (await getProduct(id))!;
    final resolved =
        kind ?? (delta < 0 ? MovementKind.sale : MovementKind.delivery);
    await pushMovement(StockMovement(
      id: _uuid.v4(),
      productId: id,
      kind: resolved,
      delta: delta,
      occurredAt: DateTime.now(),
      source: MovementSource.app,
      idempotencyKey: _uuid.v4(),
    ));
    return (await getProduct(id))!;
  }

  @override
  Future<Product> setCount(String id, int count) async {
    await pushMovement(StockMovement(
      id: _uuid.v4(),
      productId: id,
      kind: MovementKind.count,
      countedTo: count < 0 ? 0 : count,
      occurredAt: DateTime.now(),
      source: MovementSource.app,
      idempotencyKey: _uuid.v4(),
    ));
    return (await getProduct(id))!;
  }

  @override
  Future<List<StockMovement>> movementsFor(String productId) async {
    final rows = await _client
        .from('stock_movements')
        .select()
        .eq('product_id', productId)
        .order('occurred_at', ascending: false);
    return rows.map(_movementFromRemote).toList();
  }

  // ======================================================================
  // Hold
  // ======================================================================

  @override
  Future<Product> setHeld(String id, bool held) async {
    await _client.from('products').update(
        {'held': held, 'updated_at': DateTime.now().toIso8601String()}).eq(
        'id', id);
    return (await getProduct(id))!;
  }

  // ======================================================================
  // Orders
  // ======================================================================

  @override
  Future<List<ShopOrder>> getOrders() async {
    final rows = await _client
        .from('orders')
        .select('*, order_items(*)')
        .order('created_at', ascending: false);
    return rows.map(_orderFromRemote).toList();
  }

  @override
  Future<ShopOrder?> getOrder(String id) async {
    final rows = await _client
        .from('orders')
        .select('*, order_items(*)')
        .eq('id', id)
        .limit(1);
    if (rows.isEmpty) return null;
    return _orderFromRemote(rows.first);
  }

  @override
  Future<ShopOrder> setOrderStatus(String id, OrderStatus status) async {
    await _client.from('orders').update({
      'status': status.name,
      'collected_at': status == OrderStatus.collected
          ? DateTime.now().toIso8601String()
          : null,
    }).eq('id', id);
    return (await getOrder(id))!;
  }

  // ======================================================================
  // Analytics
  // ======================================================================

  @override
  Future<List<ProductSalesAggregate>> salesByProduct({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client
        .from('stock_movements')
        .select('product_id, delta, order_id, products(name, price_cents)')
        .eq('kind', 'sale')
        .gte('occurred_at', from.toIso8601String())
        .lt('occurred_at', to.toIso8601String());

    final byProduct = <String, ProductSalesAggregate>{};
    for (final r in rows) {
      final pid = r['product_id'] as String;
      final units = -((r['delta'] as int?) ?? 0);
      final product = r['products'] as Map<String, dynamic>?;
      final name = product?['name'] as String? ?? '';
      final price = (product?['price_cents'] as int?) ?? 0;
      final prev = byProduct[pid];
      byProduct[pid] = ProductSalesAggregate(
        productId: pid,
        name: name,
        unitsSold: (prev?.unitsSold ?? 0) + units,
        revenueCents: (prev?.revenueCents ?? 0) + units * price,
      );
    }
    final list = byProduct.values.toList()
      ..sort((a, b) => b.unitsSold.compareTo(a.unitsSold));
    return list;
  }

  @override
  Future<List<DailySalesPoint>> salesByDay({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client
        .from('stock_movements')
        .select('delta, occurred_at, products(price_cents)')
        .eq('kind', 'sale')
        .gte('occurred_at', from.toIso8601String())
        .lt('occurred_at', to.toIso8601String());

    final byDay = <String, DailySalesPoint>{};
    for (final r in rows) {
      final day = (r['occurred_at'] as String).substring(0, 10);
      final units = -((r['delta'] as int?) ?? 0);
      final product = r['products'] as Map<String, dynamic>?;
      final price = (product?['price_cents'] as int?) ?? 0;
      final prev = byDay[day];
      byDay[day] = DailySalesPoint(
        day: DateTime.parse('${day}T00:00:00'),
        unitsSold: (prev?.unitsSold ?? 0) + units,
        revenueCents: (prev?.revenueCents ?? 0) + units * price,
      );
    }
    final list = byDay.values.toList()..sort((a, b) => a.day.compareTo(b.day));
    return list;
  }

  // ======================================================================
  // Tags — implicit server-side (no tags table); derived from products.
  // ======================================================================

  @override
  Future<List<String>> getTags() async {
    final rows = await _client.from('products').select('tag');
    final seen = <String>{...kDefaultTags};
    final ordered = <String>[...kDefaultTags];
    for (final r in rows) {
      final t = r['tag'] as String?;
      if (t != null && seen.add(t)) ordered.add(t);
    }
    return ordered;
  }

  @override
  Future<void> addTag(String tag) async {/* implicit — set on a product's tag */}

  // ======================================================================
  // Device-local concerns — not the server's job (see class doc).
  // ======================================================================

  @override
  Future<Credentials> getCredentials() =>
      throw UnsupportedError('Credentials live behind Supabase Auth, not here.');

  @override
  Future<void> setCredentials(Credentials credentials) =>
      throw UnsupportedError('Credentials live behind Supabase Auth, not here.');

  @override
  Future<AppSettings> getSettings() =>
      throw UnsupportedError('Settings are per-device; served from local.');

  @override
  Future<void> saveSettings(AppSettings settings) =>
      throw UnsupportedError('Settings are per-device; served from local.');

  @override
  Future<void> resetAll() =>
      throw UnsupportedError('The app must never wipe the shared server.');

  // ======================================================================
  // Raw push/pull surface used by SyncingShopRepository.
  // ======================================================================

  /// Upsert a product's owner-editable attributes (last-write-wins). Never
  /// sends `stock_cached` — that is derived by the DB trigger.
  Future<void> pushProduct(Product p) async {
    await _client.from('products').upsert({
      'id': p.id,
      'legacy_id': p.legacyId,
      'name': p.name,
      'description': p.description,
      'price_cents': p.priceCents,
      'low_stock_threshold': p.lowStockThreshold,
      'tag': p.tag,
      'active': p.active,
      'held': p.held,
      'image_url': p.imageUrl,
      'image_credit': p.imageCredit,
      'barcode': p.barcode,
      'updated_at': p.updatedAt.toIso8601String(),
    });
  }

  /// Insert a ledger movement, ignoring a duplicate idempotency key — the retry
  /// safety net from §4.3 (a replay after a lost response is a success).
  Future<void> pushMovement(StockMovement m) async {
    await _client.from('stock_movements').upsert(
      {
        'id': m.id,
        'product_id': m.productId,
        'kind': m.kind.name,
        'delta': m.delta,
        'counted_to': m.countedTo,
        'occurred_at': m.occurredAt.toIso8601String(),
        'source': _sourceToDb(m.source),
        'order_id': m.orderId,
        'note': m.note,
        'idempotency_key': m.idempotencyKey,
      },
      onConflict: 'idempotency_key',
      ignoreDuplicates: true,
    );
  }

  /// Push only an order's owner-editable lifecycle (the app never rewrites the
  /// server's totals or line items).
  Future<void> pushOrderStatus(
      String id, OrderStatus status, DateTime? collectedAt) async {
    await _client.from('orders').update({
      'status': status.name,
      'collected_at': collectedAt?.toIso8601String(),
    }).eq('id', id);
  }

  Future<List<Product>> pullProductsSince(DateTime? since) async {
    var query = _client.from('products').select();
    if (since != null) {
      query = query.gt('updated_at', since.toIso8601String());
    }
    final rows = await query;
    return rows.map(_productFromRemote).toList();
  }

  Future<List<StockMovement>> pullMovementsSince(DateTime? since) async {
    var query = _client.from('stock_movements').select();
    if (since != null) {
      query = query.gt('recorded_at', since.toIso8601String());
    }
    final rows = await query.order('recorded_at', ascending: true);
    return rows.map(_movementFromRemote).toList();
  }

  Future<List<ShopOrder>> pullOrdersSince(DateTime? since) async {
    var query = _client.from('orders').select('*, order_items(*)');
    if (since != null) {
      query = query.gt('created_at', since.toIso8601String());
    }
    final rows = await query.order('created_at', ascending: true);
    return rows.map(_orderFromRemote).toList();
  }

  // ======================================================================
  // Row mapping (Supabase booleans/nesting -> app models)
  // ======================================================================

  Product _productFromRemote(Map<String, dynamic> r) => Product(
        id: r['id'] as String,
        legacyId: r['legacy_id'] as int?,
        name: r['name'] as String,
        description: (r['description'] as String?) ?? '',
        priceCents: r['price_cents'] as int,
        stock: (r['stock_cached'] as int?) ?? 0,
        lowStockThreshold: (r['low_stock_threshold'] as int?) ?? 3,
        tag: r['tag'] as String,
        active: (r['active'] as bool?) ?? true,
        held: (r['held'] as bool?) ?? false,
        imageUrl: r['image_url'] as String?,
        imageCredit: r['image_credit'] == null
            ? null
            : r['image_credit'].toString(),
        barcode: r['barcode'] as String?,
        updatedAt: DateTime.parse(r['updated_at'] as String),
      );

  StockMovement _movementFromRemote(Map<String, dynamic> r) => StockMovement(
        id: r['id'] as String,
        productId: r['product_id'] as String,
        kind: MovementKind.values.byName(r['kind'] as String),
        delta: r['delta'] as int?,
        countedTo: r['counted_to'] as int?,
        occurredAt: DateTime.parse(r['occurred_at'] as String),
        source: _sourceFromDb(r['source'] as String),
        orderId: r['order_id'] as String?,
        note: r['note'] as String?,
        idempotencyKey: r['idempotency_key'] as String,
      );

  ShopOrder _orderFromRemote(Map<String, dynamic> r) {
    final rawItems = (r['order_items'] as List<dynamic>?) ?? const [];
    final items = rawItems
        .map((e) => OrderItem(
              productId: e['product_id'] as String,
              nameAtTime: e['name_at_time'] as String,
              priceCents: e['price_cents'] as int,
              qty: e['qty'] as int,
            ))
        .toList();
    return ShopOrder(
      id: r['id'] as String,
      reference: r['reference'] as String,
      createdAt: DateTime.parse(r['created_at'] as String),
      totalCents: r['total_cents'] as int,
      paymentMethod: (r['payment_status'] as String?) == 'paid'
          ? 'Paid'
          : 'Reserve',
      items: items,
      status: OrderStatusX.fromDb(r['status'] as String?),
      customerName: r['customer_name'] as String?,
      customerPhone: r['customer_phone'] as String?,
      customerEmail: r['customer_email'] as String?,
      note: r['note'] as String?,
      collectedAt: (r['collected_at'] as String?) == null
          ? null
          : DateTime.parse(r['collected_at'] as String),
    );
  }

  static MovementSource _sourceFromDb(String s) => switch (s) {
        'web_order' => MovementSource.webOrder,
        'system' => MovementSource.system,
        _ => MovementSource.app,
      };

  static String _sourceToDb(MovementSource s) => switch (s) {
        MovementSource.webOrder => 'web_order',
        MovementSource.system => 'system',
        MovementSource.app => 'app',
      };

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
}
