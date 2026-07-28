import 'package:flutter/foundation.dart';

/// Aggregate models computed over the append-only `stock_movements` ledger.
///
/// These exist so a later analytics/reporting feature screen has a typed data
/// surface to bind to — the ledger is the single source of truth for "how much
/// did we sell", so every figure here is derived from `kind = 'sale'` movements
/// rather than a separately-maintained counter. See
/// `ShopRepository.salesByProduct` / `salesByDay`.
@immutable
class ProductSalesAggregate {
  const ProductSalesAggregate({
    required this.productId,
    required this.name,
    required this.unitsSold,
    required this.revenueCents,
  });

  final String productId;
  final String name;

  /// Positive count of units sold in the window (sale deltas are negative in
  /// the ledger; this is their magnitude).
  final int unitsSold;

  /// Units × the price snapshotted on each order line, in cents.
  final int revenueCents;
}

/// One day's sales total, for a trend line.
@immutable
class DailySalesPoint {
  const DailySalesPoint({
    required this.day,
    required this.unitsSold,
    required this.revenueCents,
  });

  /// Date at local midnight; the y-values cover that whole day.
  final DateTime day;
  final int unitsSold;
  final int revenueCents;
}
