import 'package:flutter/foundation.dart';

/// The append-only truth about stock (01-architecture.md §2.4).
///
///  * [count]    — the owner did a stocktake. [countedTo] is absolute; [delta]
///                 is ignored. Acts as a baseline "at a point in time".
///  * [sale]     — an order took units. [delta] is negative.
///  * [delivery] — stock arrived. [delta] is positive.
///  * [waste]    — damaged / returned to supplier. [delta] is negative.
///  * [adjust]   — a manual correction that is not a full recount.
///
/// Deriving stock from this ledger (rather than mutating a scalar) is what
/// makes the offline conflict resolution in §4.4 correct regardless of the
/// order in which movements arrive.
enum MovementKind { count, sale, delivery, waste, adjust }

enum MovementSource { app, webOrder, system }

@immutable
class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.kind,
    this.delta,
    this.countedTo,
    required this.occurredAt,
    required this.source,
    this.orderId,
    this.note,
    required this.idempotencyKey,
  });

  final String id;
  final String productId;
  final MovementKind kind;

  /// Signed change for non-count movements; null for a count.
  final int? delta;

  /// Absolute value for a count; null otherwise.
  final int? countedTo;

  /// CLIENT wall-clock time of the action — the ordering key for recalc.
  final DateTime occurredAt;

  final MovementSource source;
  final String? orderId;
  final String? note;

  /// Client-generated; carried to the server's unique constraint so a retry
  /// after a lost response is treated as success, not a double-apply.
  final String idempotencyKey;

  factory StockMovement.fromRow(Map<String, Object?> r) => StockMovement(
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

  Map<String, Object?> toRow() => {
        'id': id,
        'product_id': productId,
        'kind': kind.name,
        'delta': delta,
        'counted_to': countedTo,
        'occurred_at': occurredAt.toIso8601String(),
        'source': _sourceToDb(source),
        'order_id': orderId,
        'note': note,
        'idempotency_key': idempotencyKey,
      };

  static MovementSource _sourceFromDb(String s) {
    switch (s) {
      case 'web_order':
        return MovementSource.webOrder;
      case 'system':
        return MovementSource.system;
      default:
        return MovementSource.app;
    }
  }

  static String _sourceToDb(MovementSource s) {
    switch (s) {
      case MovementSource.webOrder:
        return 'web_order';
      case MovementSource.system:
        return 'system';
      case MovementSource.app:
        return 'app';
    }
  }
}
