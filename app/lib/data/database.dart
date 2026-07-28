import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens the local SQLite database and owns the schema.
///
/// The schema is a faithful local mirror of the server tables in
/// 01-architecture.md §2.4 / §4.2: `products` holds attributes + a DERIVED
/// `stock_cached`, and `stock_movements` is the append-only ledger that
/// `stock_cached` is computed from. Orders are stored read-only.
class AppDatabase {
  AppDatabase._();

  static const _fileName = 'knightsbridge.db';
  // v2 adds the order lifecycle columns (status/customer/collected_at) and the
  // `outbox` table the Supabase sync layer drains. Both are additive; a v1
  // database (a demo install from before sync existed) is migrated in place by
  // [_onUpgrade] with no data loss, and a local-only app that never sets a
  // Supabase backend simply never writes to `outbox`.
  static const _version = 2;

  static Database? _db;

  static Future<Database> instance() async {
    if (_db != null) return _db!;

    // On desktop (running from VS Code without an emulator) sqflite needs the
    // FFI implementation; mobile uses the bundled native one. This lets the
    // app be demoed with `flutter run` on Windows/macOS/Linux too.
    final bool isDesktop = !kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    String path;
    if (isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await getApplicationSupportDirectory();
      path = p.join(dir.path, _fileName);
    } else {
      path = p.join(await getDatabasesPath(), _fileName);
    }

    _db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return _db!;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id                  TEXT PRIMARY KEY,
        legacy_id           INTEGER,
        name                TEXT NOT NULL,
        description         TEXT NOT NULL DEFAULT '',
        price_cents         INTEGER NOT NULL,
        low_stock_threshold INTEGER NOT NULL DEFAULT 3,
        tag                 TEXT NOT NULL,
        active              INTEGER NOT NULL DEFAULT 1,
        held                INTEGER NOT NULL DEFAULT 0,
        image_url           TEXT,
        image_credit        TEXT,
        barcode             TEXT,
        stock_cached        INTEGER NOT NULL DEFAULT 0,
        updated_at          TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX products_active_idx ON products(active)');
    await db.execute('CREATE INDEX products_tag_idx ON products(tag)');

    await db.execute('''
      CREATE TABLE stock_movements (
        id              TEXT PRIMARY KEY,
        product_id      TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
        kind            TEXT NOT NULL,
        delta           INTEGER,
        counted_to      INTEGER,
        occurred_at     TEXT NOT NULL,
        recorded_at     TEXT NOT NULL,
        source          TEXT NOT NULL,
        order_id        TEXT,
        note            TEXT,
        idempotency_key TEXT NOT NULL UNIQUE
      )
    ''');
    await db.execute(
        'CREATE INDEX sm_product_time_idx ON stock_movements(product_id, occurred_at DESC)');

    await db.execute('''
      CREATE TABLE orders (
        id             TEXT PRIMARY KEY,
        reference      TEXT NOT NULL UNIQUE,
        created_at     TEXT NOT NULL,
        total_cents    INTEGER NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'Card',
        status         TEXT NOT NULL DEFAULT 'pending',
        customer_name  TEXT,
        customer_phone TEXT,
        customer_email TEXT,
        note           TEXT,
        collected_at   TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id     TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
        product_id   TEXT NOT NULL,
        name_at_time TEXT NOT NULL,
        price_cents  INTEGER NOT NULL,
        qty          INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tags (
        name       TEXT PRIMARY KEY,
        sort_order INTEGER NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Simple key/value store for credentials + settings (and the sync cursor).
    await db.execute('''
      CREATE TABLE kv (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await _createOutbox(db);
  }

  /// The outbound sync queue (01-architecture.md §4.2). Strict FIFO by [id].
  /// Each row names an entity whose CURRENT local state the sync worker pushes
  /// to Supabase — movements are addressed by their idempotency key (they are
  /// append-only), products/orders by id (last-write-wins upsert). Empty and
  /// unused unless a Supabase backend is configured.
  static Future<void> _createOutbox(Database db) async {
    await db.execute('''
      CREATE TABLE outbox (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,   -- 'product' | 'movement' | 'order'
        entity_id   TEXT NOT NULL,   -- product id, movement idempotency_key, order id
        operation   TEXT NOT NULL,   -- 'upsert_product' | 'delete_product'
                                     -- | 'record_movement' | 'update_order'
        created_at  TEXT NOT NULL,
        attempts    INTEGER NOT NULL DEFAULT 0,
        last_error  TEXT,
        status      TEXT NOT NULL DEFAULT 'pending'  -- pending | done | failed
      )
    ''');
    await db.execute(
        'CREATE INDEX outbox_status_idx ON outbox(status, id)');
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Order lifecycle + reserve-and-collect contact fields.
      await db.execute(
          "ALTER TABLE orders ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'");
      await db.execute('ALTER TABLE orders ADD COLUMN customer_name TEXT');
      await db.execute('ALTER TABLE orders ADD COLUMN customer_phone TEXT');
      await db.execute('ALTER TABLE orders ADD COLUMN customer_email TEXT');
      await db.execute('ALTER TABLE orders ADD COLUMN note TEXT');
      await db.execute('ALTER TABLE orders ADD COLUMN collected_at TEXT');
      await _createOutbox(db);
    }
  }

  @visibleForTesting
  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
