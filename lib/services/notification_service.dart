import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/duration_text.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'storage_optimizer';
  static const _channelName = 'Storage Optimizer';
  static const _channelDesc = 'Proactive storage management alerts';

  Future<void> initialize() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
        ));
    // No-op below Android 13, where notifications need no runtime grant.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> showStorageWarning({
    required int daysUntilFull,
    required double usedPercent,
  }) async {
    await initialize();
    final body = daysUntilFull == 0
        ? 'Storage is full! Free up space immediately.'
        : 'Storage fills in ${dayCount(daysUntilFull)}. '
            '${usedPercent.toStringAsFixed(0)}% used.';

    await _plugin.show(
      1,
      'Storage Alert',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> showScanComplete({
    required int filesFound,
    required int recommended,
  }) async {
    await initialize();
    await _plugin.show(
      2,
      'Scan Complete',
      'Found $filesFound files — $recommended recommended for deletion.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
