import 'package:equatable/equatable.dart';
import 'package:untitled1/features/notifications/domain/entities/app_notification.dart';

abstract class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object?> get props => [];
}

class NotificationsStarted extends NotificationsEvent {
  const NotificationsStarted(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}

class NotificationsUpdated extends NotificationsEvent {
  const NotificationsUpdated(this.notifications);

  final List<AppNotification> notifications;

  @override
  List<Object?> get props => [notifications];
}

class NotificationsFailed extends NotificationsEvent {
  const NotificationsFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class NotificationMarkedRead extends NotificationsEvent {
  const NotificationMarkedRead({
    required this.userId,
    required this.notificationId,
  });

  final String userId;
  final String notificationId;

  @override
  List<Object?> get props => [userId, notificationId];
}

class NotificationsMarkAllRequested extends NotificationsEvent {
  const NotificationsMarkAllRequested(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}
