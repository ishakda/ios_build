import 'package:untitled1/core/constants/supabase_constants.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/features/notifications/data/models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  Stream<List<NotificationModel>> getNotifications(String userId);
  Future<void> markAsRead(String userId, String notificationId);
  Future<void> markAllAsRead(String userId);
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  NotificationRemoteDataSourceImpl();

  @override
  Stream<List<NotificationModel>> getNotifications(String userId) {
    return SupabaseService.client
        .from(SupabaseTables.notifications)
        .stream(primaryKey: ['id'])
        .eq('userId', userId)
        .order('timestamp', ascending: false)
        .map((rows) {
          return rows
              .map(
                (row) => NotificationModel.fromJson(row, row['id'].toString()),
              )
              .toList();
        });
  }

  @override
  Future<void> markAsRead(String userId, String notificationId) async {
    await SupabaseService.client
        .from(SupabaseTables.notifications)
        .update({'isRead': true})
        .eq('id', notificationId)
        .eq('userId', userId);
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    await SupabaseService.client
        .from(SupabaseTables.notifications)
        .update({'isRead': true})
        .eq('userId', userId)
        .eq('isRead', false);
  }
}
