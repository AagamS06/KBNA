import '../models/app_settings.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';

/// THE BACKEND SEAM.
///
/// Every screen and controller talks to this interface, never to sqflite or
/// (later) Supabase directly. Today the only implementation is
/// [LocalShopRepository] (sqflite, local-first). When the Supabase sync layer
/// from 01-architecture.md §2 is built, it becomes a second implementation —
/// or a decorator that wraps the local one and drains an outbox — and NOT ONE
/// LINE OF UI CODE has to change.
///
/// The method shapes deliberately mirror the architecture's data model: stock
/// changes are expressed as ledger MOVEMENTS, not as writes to a stock scalar.
abstract class ShopRepository {
  Future<void> init();

  // --- Products ---------------------------------------------------------

  /// All active products, sorted "needs attention first, then A–Z".
  Future<List<Product>> getProducts();

  /// Removed (soft-deleted, active = false) products, for the archive screen.
  Future<List<Product>> getRemovedProducts();

  Future<Product?> getProduct(String id);

  /// Creates a product and records its opening stock as a `count` movement.
  Future<Product> addProduct(ProductDraft draft);

  /// Updates attribute fields only (name, price, tag, threshold, photo, held).
  /// Stock is never set here — use [setCount]/[adjustStock].
  /// Clear flags are nullable (abstract methods can't carry defaults); a null
  /// or false clear flag leaves the field untouched, true nulls it.
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
  });

  /// Soft delete (active = false). Recoverable from the Removed items archive.
  Future<void> removeProduct(String id);

  /// Restore a soft-deleted product.
  Future<void> restoreProduct(String id);

  /// Permanently delete a removed product. Only permitted on inactive rows.
  Future<void> deleteProductForever(String id);

  Future<Product> duplicateProduct(String id);

  // --- Stock (ledger) ---------------------------------------------------

  /// Records a signed movement (delivery/sale/waste/adjust) and returns the
  /// product with its recalculated stock and auto-hold state applied. When
  /// [kind] is null it is inferred from the sign of [delta].
  Future<Product> adjustStock(String id, int delta, {MovementKind? kind});

  /// Records an absolute stocktake `count` and returns the updated product.
  Future<Product> setCount(String id, int count);

  Future<List<StockMovement>> movementsFor(String productId);

  // --- Hold -------------------------------------------------------------

  Future<Product> setHeld(String id, bool held);

  // --- Orders (read-only) ----------------------------------------------

  Future<List<ShopOrder>> getOrders();
  Future<ShopOrder?> getOrder(String id);

  // --- Tags / categories ------------------------------------------------

  /// Default tags followed by any custom tags, in the website's order.
  Future<List<String>> getTags();
  Future<void> addTag(String tag);

  // --- Credentials + settings ------------------------------------------

  Future<Credentials> getCredentials();
  Future<void> setCredentials(Credentials credentials);

  Future<AppSettings> getSettings();
  Future<void> saveSettings(AppSettings settings);

  // --- Data lifecycle ---------------------------------------------------

  /// Wipe everything and re-seed the sample catalogue (Settings → Start again).
  Future<void> resetAll();
}
