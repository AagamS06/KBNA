import '../models/product.dart';

/// The default categories, in the website's order (web-design/js/app.js
/// `DEFAULT_TAGS`). Custom tags added by the owner sort after these, A–Z.
const List<String> kDefaultTags = [
  'Magazine',
  'Paper',
  'Toys',
  'Cards',
  'Stationery',
  'Gifts',
  'Lottery',
];

/// A seed product, before it is given a uuid and an opening `count` movement.
class SeedProduct {
  const SeedProduct({
    required this.legacyId,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.stock,
    required this.lowStockThreshold,
    required this.tag,
  });

  final int legacyId;
  final String name;
  final String description;
  final int priceCents;
  final int stock;
  final int lowStockThreshold;
  final String tag;
}

/// The 12 sample products, copied verbatim from web-design/js/app.js
/// `SEED_PRODUCTS` (same names, descriptions, prices in cents, stock levels and
/// thresholds). Opening stock is recorded as a `count` movement at seed time so
/// the ledger is the single source of truth from the very first run.
const List<SeedProduct> kSeedProducts = [
  SeedProduct(legacyId: 1, name: 'The Daily Telegraph (Weekday)', description: "Today's edition, delivered fresh each morning.", priceCents: 260, stock: 40, lowStockThreshold: 10, tag: 'Paper'),
  SeedProduct(legacyId: 2, name: 'The Sydney Morning Herald (Weekend)', description: 'Saturday edition with all the lift-outs.', priceCents: 450, stock: 30, lowStockThreshold: 8, tag: 'Paper'),
  SeedProduct(legacyId: 3, name: "Woman's Day Magazine", description: 'Latest weekly issue.', priceCents: 620, stock: 15, lowStockThreshold: 4, tag: 'Magazine'),
  SeedProduct(legacyId: 4, name: 'National Geographic', description: 'Current monthly issue.', priceCents: 1450, stock: 8, lowStockThreshold: 3, tag: 'Magazine'),
  SeedProduct(legacyId: 5, name: "That's Life Puzzler", description: 'Crosswords and puzzles — a customer favourite.', priceCents: 550, stock: 20, lowStockThreshold: 5, tag: 'Magazine'),
  SeedProduct(legacyId: 6, name: 'Birthday Card — Classic Range', description: 'Assorted designs with envelope.', priceCents: 795, stock: 25, lowStockThreshold: 6, tag: 'Cards'),
  SeedProduct(legacyId: 7, name: 'Sympathy Card', description: 'Thoughtful designs with envelope.', priceCents: 750, stock: 12, lowStockThreshold: 4, tag: 'Cards'),
  SeedProduct(legacyId: 8, name: 'Matchbox Diecast Car', description: 'Assorted models — great little gift.', priceCents: 500, stock: 18, lowStockThreshold: 5, tag: 'Toys'),
  SeedProduct(legacyId: 9, name: 'Crayola Coloured Pencils (12 pack)', description: 'Full colour set for school or home.', priceCents: 649, stock: 14, lowStockThreshold: 4, tag: 'Stationery'),
  SeedProduct(legacyId: 10, name: 'A4 Spiral Notebook 120pg', description: 'Ruled pages, sturdy cover.', priceCents: 425, stock: 22, lowStockThreshold: 6, tag: 'Stationery'),
  SeedProduct(legacyId: 11, name: 'Gift Wrap Roll — Assorted', description: '3 metres of quality wrap.', priceCents: 495, stock: 16, lowStockThreshold: 5, tag: 'Gifts'),
  SeedProduct(legacyId: 12, name: 'Scented Candle — Vanilla', description: 'Popular local gift line.', priceCents: 1295, stock: 6, lowStockThreshold: 3, tag: 'Gifts'),
];

/// A seed online order (a reservation), applied as `sale` movements so the
/// ledger + auto-hold reproduce the website's fulfilOrder() behaviour and the
/// Today screen has a realistic "needs attention" state on first run. These
/// three orders push National Geographic, Scented Candle and Sympathy Card to
/// or below their alert levels — matching the wireframes in §2.2/§2.3.
class SeedOrder {
  const SeedOrder({
    required this.reference,
    required this.minutesAgo,
    required this.paymentMethod,
    required this.lines,
  });

  final String reference;
  final int minutesAgo;
  final String paymentMethod;

  /// legacyId -> qty
  final List<SeedOrderLine> lines;
}

class SeedOrderLine {
  const SeedOrderLine(this.legacyId, this.qty);
  final int legacyId;
  final int qty;
}

const List<SeedOrder> kSeedOrders = [
  SeedOrder(
    reference: 'KN-100482',
    minutesAgo: 320, // ~ today, mid-morning
    paymentMethod: 'Card',
    lines: [SeedOrderLine(4, 5), SeedOrderLine(8, 2)], // Nat Geo x5 -> 3 (held), Matchbox x2
  ),
  SeedOrder(
    reference: 'KN-100477',
    minutesAgo: 1180, // yesterday afternoon
    paymentMethod: 'PayPal',
    lines: [SeedOrderLine(12, 4)], // Candle x4 -> 2 (held)
  ),
  SeedOrder(
    reference: 'KN-100461',
    minutesAgo: 3120, // a couple of days ago
    paymentMethod: 'Card',
    lines: [SeedOrderLine(7, 8), SeedOrderLine(10, 2)], // Sympathy x8 -> 4 (low), Notebook x2
  ),
];
