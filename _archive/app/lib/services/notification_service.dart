import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/order.dart';
import '../models/product.dart';

/// THE NOTIFICATION SEAM.
///
/// Screens, controllers and the repository never talk to a notification plugin
/// directly — only to this interface. Today the concrete implementation is
/// [LocalNotificationService] (on-device alerts via flutter_local_notifications,
/// §5.1 "Local notifications too"). Remote push (FCM/APNs via the Expo/Supabase
/// path in §5.2–5.5) slots in later behind [PushRegistrar] without any screen
/// change — see the note on that class.
///
/// Every method is safe to call on any platform: on web/Windows or before
/// [init] succeeds, the local implementation degrades to a no-op rather than
/// throwing, so `flutter run` on desktop behaves exactly as before.
abstract class NotificationService {
  /// Initialise the platform plugin. Idempotent; safe to await at app start.
  Future<void> init();

  /// Ask the OS for permission to post notifications (iOS always; Android 13+).
  /// Returns whether permission is granted. Follows the spec's "ask after the
  /// first sign-in, not on cold launch" rule — the CALLER decides when.
  Future<bool> requestPermission();

  /// A low-stock crossing detected locally (works with no signal). Deduped to
  /// at most once per product per day (§5.1).
  Future<void> showLowStock(Product product);

  /// A new online reservation arrived (discovered when the sync layer pulls).
  Future<void> showNewOrder(ShopOrder order);
}

/// The remote-push extension point (deliberately NOT implemented here).
///
/// When push is wired up (§5.5(a)), an implementation registers the device's
/// FCM/APNs token and upserts it into the Supabase `devices` table; the server
/// fans out via the Expo push service. Nothing about the app's notification
/// *presentation* changes — a delivered push is handed to the same OS surface
/// [LocalNotificationService] already uses. Keeping this a separate seam is why
/// no screen needs to know whether an alert originated locally or from a server.
abstract class PushRegistrar {
  /// Returns the device push token to store server-side, or null if unavailable
  /// (no hardware, permission denied, or not yet built).
  Future<String?> registerDeviceToken();
}

/// The default seam wiring for `--dart-define`-free runs and tests: does
/// nothing, never throws. Also the implementation used on platforms where local
/// notifications aren't supported.
class NoopNotificationService implements NotificationService {
  const NoopNotificationService();

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> showLowStock(Product product) async {}

  @override
  Future<void> showNewOrder(ShopOrder order) async {}
}

/// On-device notifications via flutter_local_notifications.
///
/// Handles only the two immediate alerts the app can raise on its own
/// (low-stock crossing, new order). The 06:30 morning digest is a *scheduled*
/// server job (§5.5(d) pg_cron) and is intentionally not built here.
class LocalNotificationService implements NotificationService {
  LocalNotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  bool _supported = false;

  /// In-memory low-stock dedupe: `productId -> yyyy-mm-dd already alerted`.
  /// The authoritative cross-device dedupe is the server's `alerts_sent` table
  /// (§2.4); this just stops a local storm while the app is open.
  final Map<String, String> _lowStockSentOn = {};

  static const _lowStockChannel = AndroidNotificationChannel(
    'low_stock',
    'Low stock',
    description: 'Alerts when an item drops to its warn-me level.',
    importance: Importance.high,
  );
  static const _ordersChannel = AndroidNotificationChannel(
    'orders',
    'New orders',
    description: 'Alerts when a new online reservation comes in.',
    importance: Importance.high,
  );

  bool get _platformSupported {
    if (kIsWeb) return false;
    // flutter_local_notifications supports Android, iOS, macOS and Linux. On
    // Windows there is no plugin implementation, so we stay a no-op there (the
    // desktop demo path from the README).
    return Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isLinux;
  }

  @override
  Future<void> init() async {
    if (_ready) return;
    _supported = _platformSupported;
    if (!_supported) {
      _ready = true; // "ready" = we've decided; every call below no-ops.
      return;
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // We request explicitly in requestPermission(), after first sign-in.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      linux:
          LinuxInitializationSettings(defaultActionName: 'Open Knightsbridge'),
    );
    try {
      await _plugin.initialize(settings);
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_lowStockChannel);
      await android?.createNotificationChannel(_ordersChannel);
    } catch (_) {
      // Initialisation is best-effort; a failure must never break app start.
      _supported = false;
    }
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_ready) await init();
    if (!_supported) return false;
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final macos = _plugin.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
        final granted = await (ios?.requestPermissions(
                alert: true, badge: true, sound: true) ??
            macos?.requestPermissions(alert: true, badge: true, sound: true));
        return granted ?? false;
      }
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await android?.requestNotificationsPermission() ?? true;
      }
    } catch (_) {
      return false;
    }
    return true;
  }

  @override
  Future<void> showLowStock(Product product) async {
    if (!_ready) await init();
    if (!_supported) return;

    final today = _dayKey(DateTime.now());
    if (_lowStockSentOn[product.id] == today) return; // already alerted today
    _lowStockSentOn[product.id] = today;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'low_stock',
        'Low stock',
        channelDescription: 'Alerts when an item drops to its warn-me level.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );
    try {
      await _plugin.show(
        // Stable id per product so a same-day repeat replaces rather than piles.
        product.id.hashCode & 0x7fffffff,
        'Low stock: ${product.name}',
        '${product.stock} left. Tap to restock.',
        details,
        payload: 'item/${product.id}',
      );
    } catch (_) {/* never let a notification failure surface to the owner */}
  }

  @override
  Future<void> showNewOrder(ShopOrder order) async {
    if (!_ready) await init();
    if (!_supported) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'orders',
        'New orders',
        channelDescription: 'Alerts when a new online reservation comes in.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );
    final who = order.customerName == null ? '' : '${order.customerName} — ';
    try {
      await _plugin.show(
        order.id.hashCode & 0x7fffffff,
        'New order ${order.reference}',
        '$who${order.itemCount} '
            '${order.itemCount == 1 ? 'item' : 'items'}, '
            '\$${(order.totalCents / 100).toStringAsFixed(2)}',
        details,
        payload: 'order/${order.id}',
      );
    } catch (_) {/* best-effort */}
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
