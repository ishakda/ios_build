import 'package:untitled1/features/notifications/domain/entities/app_notification.dart';

abstract class NotificationRepository {
  Stream<List<AppNotification>> getNotifications(String userId);
  Future<void> markAsRead(String userId, String notificationId);
  Future<void> markAllAsRead(String userId);
}
