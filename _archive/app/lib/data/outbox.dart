import 'package:sqflite/sqflite.dart';

import 'database.dart';
import 'sync_hooks.dart';

/// One queued change awaiting push to Supabase.
class OutboxEntry {
  OutboxEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.attempts,
    this.lastError,
  });

  final int id;
  final String entityType; // 'product' | 'movement' | 'order'
  final String entityId; // product id | movement idempotency_key | order id
  final String operation;
  final int attempts;
  final String? lastError;

  factory OutboxEntry.fromRow(Map<String, Object?> r) => OutboxEntry(
        id: r['id'] as int,
        entityType: r['entity_type'] as String,
        entityId: r['entity_id'] as String,
        operation: r['operation'] as String,
        attempts: (r['attempts'] as int?) ?? 0,
        lastError: r['last_error'] as String?,
      );
}

/// The outbound sync queue, backed by the shared `outbox` table.
///
/// Also the concrete [SyncHooks] the local repository calls — enqueueing here
/// is the entire write-side of the local-first flow: the UI has already been
/// served from sqflite by the time these run.
class Outbox implements SyncHooks {
  Outbox();

  /// The `outbox` table lives in the same singleton database the local
  /// repository opens, so we resolve it lazily rather than hold a reference the
  /// caller would have to await before constructing us.
  Future<Database> get _db => AppDatabase.instance();

  Future<void> _enqueue(
    String entityType,
    String entityId,
    String operation,
  ) async {
    final db = await _db;
    // Coalesce: if an identical operation for the same entity is still pending,
    // don't stack a duplicate — the worker pushes CURRENT state, so one pending
    // upsert covers any number of edits made before it drains. Movements are
    // never coalesced (each is a distinct append addressed by a unique key).
    if (operation != 'record_movement') {
      final dupes = await db.query(
        'outbox',
        where:
            'entity_type = ? AND entity_id = ? AND operation = ? AND status = ?',
        whereArgs: [entityType, entityId, operation, 'pending'],
        limit: 1,
      );
      if (dupes.isNotEmpty) return;
    }
    await db.insert('outbox', {
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'created_at': DateTime.now().toIso8601String(),
      'attempts': 0,
      'status': 'pending',
    });
  }

  // --- SyncHooks --------------------------------------------------------

  @override
  Future<void> onProductChanged(String productId) =>
      _enqueue('product', productId, 'upsert_product');

  @override
  Future<void> onProductDeleted(String productId) =>
      _enqueue('product', productId, 'delete_product');

  @override
  Future<void> onMovementRecorded(String idempotencyKey, String productId) =>
      _enqueue('movement', idempotencyKey, 'record_movement');

  @override
  Future<void> onOrderChanged(String orderId) =>
      _enqueue('order', orderId, 'update_order');

  // --- Drain-side API (used by the sync worker) -------------------------

  /// Pending entries in strict FIFO order.
  Future<List<OutboxEntry>> pending({int limit = 100}) async {
    final db = await _db;
    final rows = await db.query(
      'outbox',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'id ASC',
      limit: limit,
    );
    return rows.map(OutboxEntry.fromRow).toList();
  }

  Future<int> pendingCount() async {
    final db = await _db;
    final rows =
        await db.rawQuery("SELECT COUNT(*) FROM outbox WHERE status = 'pending'");
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> failedCount() async {
    final db = await _db;
    final rows =
        await db.rawQuery("SELECT COUNT(*) FROM outbox WHERE status = 'failed'");
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> markDone(int id) async {
    final db = await _db;
    await db.update('outbox', {'status': 'done'},
        where: 'id = ?', whereArgs: [id]);
  }

  /// A terminal failure (a 4xx that isn't auth/throttle). Kept, not dropped, so
  /// the "Sync problems" screen can surface it (§4.5). Never silently discard.
  Future<void> markFailed(int id, String error) async {
    final db = await _db;
    await db.update('outbox', {'status': 'failed', 'last_error': error},
        where: 'id = ?', whereArgs: [id]);
  }

  /// A transient failure (network / 5xx / auth): bump the attempt count and
  /// leave it pending for the next drain (backoff lives in the worker).
  Future<void> markRetry(int id, int attempts, String error) async {
    final db = await _db;
    await db.update('outbox', {'attempts': attempts, 'last_error': error},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Re-queue every failed row (the "Retry" button on the Sync problems screen).
  Future<void> retryAllFailed() async {
    final db = await _db;
    await db.update('outbox',
        {'status': 'pending', 'attempts': 0, 'last_error': null},
        where: 'status = ?', whereArgs: ['failed']);
  }
}
