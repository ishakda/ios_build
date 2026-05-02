import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/features/notifications/domain/entities/app_notification.dart';

class NotificationModel extends AppNotification {
  const NotificationModel({
    required super.id,
    required super.title,
    required super.body,
    required super.timestamp,
    required super.type,
    super.isRead,
    super.data,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json, String id) {
    return NotificationModel(
      id: id,
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      timestamp: SupabaseService.parseDateTime(json['timestamp']),
      type: json['type'] ?? 'system',
      isRead: json['isRead'] ?? false,
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'type': type,
      'isRead': isRead,
      'data': data,
    };
  }
}
