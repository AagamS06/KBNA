import 'package:flutter/foundation.dart';

/// The status a product row / detail shows. Never carried by colour alone in
/// the UI — always paired with the word and (for low/hold) a leading rule.
enum ProductStatus { ok, low, soldOut }

/// A stock item.
///
/// Matches the website's domain model in web-design/js/app.js exactly:
///   { id, name, description, price_cents, stock, low_stock_threshold, tag,
///     active, held, image_url, image_credit }
/// plus two additions the UX/architecture docs introduce:
///   * [barcode] — 01-architecture.md §9(2): "worth a barcode field on the
///     product record now, even if the scanner ships later".
///   * [legacyId] — the 1..12 ids from the original localStorage seed, kept so
///     a future Supabase migration can reconcile rows.
///
/// [stock] here is the DERIVED value (the architecture's `stock_cached`): it is
/// computed from the append-only stock_movements ledger, never written to
/// directly. See LocalShopRepository for the recalc.
@immutable
class Product {
  const Product({
    required this.id,
    this.legacyId,
    required this.name,
    this.description = '',
    required this.priceCents,
    required this.stock,
    this.lowStockThreshold = 3,
    required this.tag,
    this.active = true,
    this.held = false,
    this.imageUrl,
    this.imageCredit,
    this.barcode,
    required this.updatedAt,
  });

  final String id;
  final int? legacyId;
  final String name;
  final String description;
  final int priceCents;
  final int stock;
  final int lowStockThreshold;
  final String tag;
  final bool active;
  final bool held;
  final String? imageUrl;

  /// The Openverse licence block, stored verbatim as a JSON string (jsonb on
  /// the server). Rendered as the CC attribution line under a photo.
  final String? imageCredit;

  final String? barcode;
  final DateTime updatedAt;

  bool get isSoldOut => stock <= 0;

  /// Low = at or below the alert level (matches the auto-hold trigger).
  bool get isLow => stock <= lowStockThreshold;

  ProductStatus get status {
    if (isSoldOut) return ProductStatus.soldOut;
    if (isLow) return ProductStatus.low;
    return ProductStatus.ok;
  }

  /// True when the item needs the owner's attention on the Today screen.
  bool get needsAttention => active && (held || isSoldOut || isLow);

  Product copyWith({
    String? name,
    String? description,
    int? priceCents,
    int? stock,
    int? lowStockThreshold,
    String? tag,
    bool? active,
    bool? held,
    String? imageUrl,
    bool clearImageUrl = false,
    String? imageCredit,
    bool clearImageCredit = false,
    String? barcode,
    bool clearBarcode = false,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id,
      legacyId: legacyId,
      name: name ?? this.name,
      description: description ?? this.description,
      priceCents: priceCents ?? this.priceCents,
      stock: stock ?? this.stock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      tag: tag ?? this.tag,
      active: active ?? this.active,
      held: held ?? this.held,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      imageCredit: clearImageCredit ? null : (imageCredit ?? this.imageCredit),
      barcode: clearBarcode ? null : (barcode ?? this.barcode),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Product.fromRow(Map<String, Object?> r) => Product(
        id: r['id'] as String,
        legacyId: r['legacy_id'] as int?,
        name: r['name'] as String,
        description: (r['description'] as String?) ?? '',
        priceCents: r['price_cents'] as int,
        stock: (r['stock_cached'] as int?) ?? 0,
        lowStockThreshold: (r['low_stock_threshold'] as int?) ?? 3,
        tag: r['tag'] as String,
        active: (r['active'] as int? ?? 1) == 1,
        held: (r['held'] as int? ?? 0) == 1,
        imageUrl: r['image_url'] as String?,
        imageCredit: r['image_credit'] as String?,
        barcode: r['barcode'] as String?,
        updatedAt: DateTime.parse(r['updated_at'] as String),
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'legacy_id': legacyId,
        'name': name,
        'description': description,
        'price_cents': priceCents,
        'low_stock_threshold': lowStockThreshold,
        'tag': tag,
        'active': active ? 1 : 0,
        'held': held ? 1 : 0,
        'image_url': imageUrl,
        'image_credit': imageCredit,
        'barcode': barcode,
        'stock_cached': stock,
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// A validated draft used when adding or editing a product. Keeping this
/// separate from [Product] means the form never has to fabricate an id, a
/// derived stock value, or an updatedAt.
@immutable
class ProductDraft {
  const ProductDraft({
    required this.name,
    required this.description,
    required this.priceCents,
    required this.initialStock,
    required this.lowStockThreshold,
    required this.tag,
    this.held = false,
    this.imageUrl,
    this.imageCredit,
    this.barcode,
  });

  final String name;
  final String description;
  final int priceCents;
  final int initialStock;
  final int lowStockThreshold;
  final String tag;
  final bool held;
  final String? imageUrl;
  final String? imageCredit;
  final String? barcode;
}
