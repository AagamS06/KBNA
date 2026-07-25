import 'package:flutter/foundation.dart';

/// One line of an online order. Name and price are SNAPSHOTTED at reservation
/// time so a later product edit never rewrites history (§2.4 order_items).
@immutable
class OrderItem {
  const OrderItem({
    required this.productId,
    required this.nameAtTime,
    required this.priceCents,
    required this.qty,
  });

  final String productId;
  final String nameAtTime;
  final int priceCents;
  final int qty;

  int get lineTotalCents => priceCents * qty;

  factory OrderItem.fromRow(Map<String, Object?> r) => OrderItem(
        productId: r['product_id'] as String,
        nameAtTime: r['name_at_time'] as String,
        priceCents: r['price_cents'] as int,
        qty: r['qty'] as int,
      );

  Map<String, Object?> toRow(String orderId) => {
        'order_id': orderId,
        'product_id': productId,
        'name_at_time': nameAtTime,
        'price_cents': priceCents,
        'qty': qty,
      };
}

/// A reservation placed on the website. Read-only in the owner app (matching
/// the website's scope decision — reserve-and-collect, not e-commerce).
@immutable
class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.reference,
    required this.createdAt,
    required this.totalCents,
    required this.paymentMethod,
    required this.items,
  });

  final String id;
  final String reference; // human-readable, e.g. 'KN-100482'
  final DateTime createdAt;
  final int totalCents;
  final String paymentMethod; // 'Card' | 'PayPal' | ...
  final List<OrderItem> items;

  int get itemCount => items.fold(0, (n, i) => n + i.qty);

  factory ShopOrder.fromRow(Map<String, Object?> r, List<OrderItem> items) =>
      ShopOrder(
        id: r['id'] as String,
        reference: r['reference'] as String,
        createdAt: DateTime.parse(r['created_at'] as String),
        totalCents: r['total_cents'] as int,
        paymentMethod: (r['payment_method'] as String?) ?? 'Card',
        items: items,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'reference': reference,
        'created_at': createdAt.toIso8601String(),
        'total_cents': totalCents,
        'payment_method': paymentMethod,
      };
}
