import 'package:flutter_test/flutter_test.dart';
import 'package:knightsbridge_owner/models/order.dart';
import 'package:knightsbridge_owner/models/product.dart';

/// Pure-model smoke tests — no database, no Flutter bindings — so `flutter test`
/// (and therefore CI) has something to run without a device or emulator. Later
/// feature agents should add their own tests alongside these.
void main() {
  Product product({int stock = 10, int threshold = 3, bool held = false}) =>
      Product(
        id: 'p1',
        name: 'National Geographic',
        priceCents: 995,
        stock: stock,
        lowStockThreshold: threshold,
        tag: 'Magazines',
        held: held,
        updatedAt: DateTime(2026, 1, 1),
      );

  group('Product.status', () {
    test('ok when comfortably above the alert level', () {
      expect(product(stock: 10).status, ProductStatus.ok);
      expect(product(stock: 10).isLow, isFalse);
    });

    test('low at or below the alert level', () {
      expect(product(stock: 3).status, ProductStatus.low);
      expect(product(stock: 3).isLow, isTrue);
    });

    test('sold out at zero', () {
      expect(product(stock: 0).status, ProductStatus.soldOut);
      expect(product(stock: 0).isSoldOut, isTrue);
    });

    test('needsAttention when held even if in stock', () {
      expect(product(stock: 10, held: true).needsAttention, isTrue);
    });
  });

  group('OrderStatus', () {
    test('fromDb maps known values and falls back to pending', () {
      expect(OrderStatusX.fromDb('ready'), OrderStatus.ready);
      expect(OrderStatusX.fromDb('collected'), OrderStatus.collected);
      expect(OrderStatusX.fromDb(null), OrderStatus.pending);
      expect(OrderStatusX.fromDb('nonsense'), OrderStatus.pending);
    });

    test('isOpen only for pending/ready', () {
      expect(OrderStatus.pending.isOpen, isTrue);
      expect(OrderStatus.ready.isOpen, isTrue);
      expect(OrderStatus.collected.isOpen, isFalse);
      expect(OrderStatus.cancelled.isOpen, isFalse);
    });
  });
}
