import 'package:untitled1/features/notifications/data/datasources/notification_remote_data_source.dart';
import 'package:untitled1/features/notifications/domain/entities/app_notification.dart';
import 'package:untitled1/features/notifications/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({required this.remoteDataSource});

  final NotificationRemoteDataSource remoteDataSource;

  @override
  Stream<List<AppNotification>> getNotifications(String userId) {
    return remoteDataSource.getNotifications(userId);
  }

  @override
  Future<void> markAsRead(String userId, String notificationId) {
    return remoteDataSource.markAsRead(userId, notificationId);
  }

  @override
  Future<void> markAllAsRead(String userId) {
    return remoteDataSource.markAllAsRead(userId);
  }
}
