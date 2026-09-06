/// The write-side seam between the local store and the sync layer.
///
/// [LocalShopRepository] takes an optional [SyncHooks]. When it is null (the
/// default, and the ONLY configuration when no Supabase backend is set) the
/// local repository behaves byte-for-byte as it always has — every hook call is
/// a null-safe no-op. When a Supabase backend is configured, the syncing
/// decorator passes an implementation that appends a row to the `outbox` for
/// every mutation, right where the mutation happens (so the enqueue is ordered
/// with, and adjacent to, the local write).
///
/// Reads never touch this seam — the whole point of local-first is that reads
/// are pure sqflite.
abstract class SyncHooks {
  /// A product's attributes changed (create, edit, hold, soft-delete, restore).
  /// The worker will push the product's current local state.
  Future<void> onProductChanged(String productId);

  /// A product was hard-deleted from the local store.
  Future<void> onProductDeleted(String productId);

  /// A ledger movement was appended. Addressed by its idempotency key because
  /// movements are append-only and the key carries the server's dedupe
  /// guarantee (§4.3).
  Future<void> onMovementRecorded(String idempotencyKey, String productId);

  /// An order's owner-editable state changed (its lifecycle status).
  Future<void> onOrderChanged(String orderId);
}

/// The read-side seam for the recompute step. [LocalShopRepository] fires this
/// whenever a ledger recompute pushes a product from above its alert level to
/// at/below it — i.e. a real low-stock CROSSING, not merely "is low". The local
/// notification service listens here so a low-stock alert can fire even with no
/// signal (§5.1, "Local notifications too"). Null = no observer = no-op.
abstract class LedgerObserver {
  /// [productId] just crossed down to/through its low-stock threshold.
  void onLowStockCrossed(String productId);
}
