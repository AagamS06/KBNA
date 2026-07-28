import 'package:flutter/foundation.dart';

/// The reservation lifecycle (01-architecture.md §2.4 `orders.status`).
///
/// A website reservation lands as [pending]; the owner marks it [ready] once
/// it's pulled and waiting behind the counter, [collected] when the customer
/// picks it up, or [cancelled] if it falls through. This is the state machine a
/// later "click & collect" feature screen drives — the data + repository seam
/// for it exist now even though the screen doesn't.
enum OrderStatus { pending, ready, collected, cancelled }

extension OrderStatusX on OrderStatus {
  /// Plain-English label (never shown as the raw enum name).
  String get label => switch (this) {
        OrderStatus.pending => 'New',
        OrderStatus.ready => 'Ready to collect',
        OrderStatus.collected => 'Collected',
        OrderStatus.cancelled => 'Cancelled',
      };

  /// Whether this order is still waiting on the owner (drives the Today badge).
  bool get isOpen =>
      this == OrderStatus.pending || this == OrderStatus.ready;

  static OrderStatus fromDb(String? s) => OrderStatus.values.firstWhere(
        (e) => e.name == s,
        orElse: () => OrderStatus.pending,
      );
}

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

/// A reservation placed on the website. The owner app can read it and move it
/// along its [status] lifecycle (reserve-and-collect scope — the app never
/// creates or prices orders; the website's Edge Function does that, §2.7).
@immutable
class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.reference,
    required this.createdAt,
    required this.totalCents,
    required this.paymentMethod,
    required this.items,
    this.status = OrderStatus.pending,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.note,
    this.collectedAt,
  });

  final String id;
  final String reference; // human-readable, e.g. 'KN-100482'
  final DateTime createdAt;
  final int totalCents;
  final String paymentMethod; // 'Card' | 'PayPal' | 'Reserve' | ...
  final List<OrderItem> items;

  /// Where in the pending -> ready -> collected lifecycle this order is.
  final OrderStatus status;

  // Reserve-and-collect contact details (nullable on legacy/simulated orders).
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? note;
  final DateTime? collectedAt;

  int get itemCount => items.fold(0, (n, i) => n + i.qty);

  ShopOrder copyWith({
    OrderStatus? status,
    DateTime? collectedAt,
    bool clearCollectedAt = false,
  }) {
    return ShopOrder(
      id: id,
      reference: reference,
      createdAt: createdAt,
      totalCents: totalCents,
      paymentMethod: paymentMethod,
      items: items,
      status: status ?? this.status,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      note: note,
      collectedAt: clearCollectedAt ? null : (collectedAt ?? this.collectedAt),
    );
  }

  factory ShopOrder.fromRow(Map<String, Object?> r, List<OrderItem> items) =>
      ShopOrder(
        id: r['id'] as String,
        reference: r['reference'] as String,
        createdAt: DateTime.parse(r['created_at'] as String),
        totalCents: r['total_cents'] as int,
        paymentMethod: (r['payment_method'] as String?) ?? 'Card',
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

  Map<String, Object?> toRow() => {
        'id': id,
        'reference': reference,
        'created_at': createdAt.toIso8601String(),
        'total_cents': totalCents,
        'payment_method': paymentMethod,
        'status': status.name,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_email': customerEmail,
        'note': note,
        'collected_at': collectedAt?.toIso8601String(),
      };
}
