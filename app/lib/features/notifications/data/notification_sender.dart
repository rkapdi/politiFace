// lib/features/notifications/data/notification_sender.dart
//
// Thin seam over NotificationService so WashingtonWatchService and
// ChapterReadyService never touch the platform channel directly. Tests
// inject a fake implementation instead of the plugin-backed one.

import 'notification_service.dart';

abstract class NotificationSender {
  /// Whether the OS currently authorizes notifications (does not prompt).
  Future<bool> isAuthorized();

  /// Fires an immediate notification.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  /// Arms a one-off notification for a future [when].
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  });

  /// Cancels a pending/delivered notification by [id].
  Future<void> cancel(int id);
}

/// Production implementation: forwards to the real
/// [NotificationService] singleton and its platform-channel plugin.
class PluginNotificationSender implements NotificationSender {
  const PluginNotificationSender();

  @override
  Future<bool> isAuthorized() => NotificationService.instance.isAuthorized();

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) =>
      NotificationService.instance.show(
        id: id,
        title: title,
        body: body,
        payload: payload,
      );

  @override
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) =>
      NotificationService.instance.scheduleAt(
        id: id,
        title: title,
        body: body,
        when: when,
        payload: payload,
      );

  @override
  Future<void> cancel(int id) => NotificationService.instance.cancelId(id);
}
