import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules / cancels the daily streak-reminder local notification.
/// iOS-only for V1; Android wiring is no-op-friendly.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _streakReminderId = 1;
  static const _channelId = 'streak_reminder';
  static const int _hour = 19;   // 7 PM local
  static const int _minute = 0;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(iOS: ios, android: android),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await init();
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return granted ?? false;
  }

  /// Returns the OS's current notification authorization state without
  /// prompting the user. Used to detect when the user revoked notifications
  /// in iOS Settings → Notifications after we'd asked for them.
  Future<bool> isAuthorized() async {
    await init();
    final opts = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.checkPermissions();
    return opts?.isEnabled ?? false;
  }

  Future<void> scheduleDailyReminder() async {
    await init();
    await _plugin.zonedSchedule(
      _streakReminderId,
      'Keep your streak going',
      "Today's deck is waiting. Even one card counts.",
      _nextInstance(_hour, _minute),
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        android: AndroidNotificationDetails(
          _channelId,
          'Streak reminder',
          channelDescription: 'Daily nudge so your streak survives.',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel() async {
    await init();
    await _plugin.cancel(_streakReminderId);
  }

  static tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
