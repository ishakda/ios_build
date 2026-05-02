import 'package:equatable/equatable.dart';
import 'package:untitled1/features/notifications/domain/entities/app_notification.dart';

abstract class NotificationsState extends Equatable {
  const NotificationsState();

  @override
  List<Object?> get props => [];
}

class NotificationsInitial extends NotificationsState {}

class NotificationsLoading extends NotificationsState {}

class NotificationsLoaded extends NotificationsState {
  const NotificationsLoaded(this.notifications);

  final List<AppNotification> notifications;

  @override
  List<Object?> get props => [notifications];
}

class NotificationsFailure extends NotificationsState {
  const NotificationsFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class NotificationsActionInProgress extends NotificationsState {
  const NotificationsActionInProgress(this.notifications);

  final List<AppNotification> notifications;

  @override
  List<Object?> get props => [notifications];
}

class NotificationsActionFailure extends NotificationsState {
  const NotificationsActionFailure({
    required this.notifications,
    required this.message,
  });

  final List<AppNotification> notifications;
  final String message;

  @override
  List<Object?> get props => [notifications, message];
}
