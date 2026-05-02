import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/features/notifications/domain/entities/app_notification.dart';
import 'package:untitled1/features/notifications/domain/repositories/notification_repository.dart';
import 'package:untitled1/features/notifications/presentation/bloc/notifications_event.dart';
import 'package:untitled1/features/notifications/presentation/bloc/notifications_state.dart';

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  NotificationsBloc({required this.notificationRepository})
    : super(NotificationsInitial()) {
    on<NotificationsStarted>(_onStarted);
    on<NotificationsUpdated>(_onUpdated);
    on<NotificationsFailed>(_onFailed);
    on<NotificationMarkedRead>(_onMarkedRead);
    on<NotificationsMarkAllRequested>(_onMarkAllRequested);
  }

  final NotificationRepository notificationRepository;
  StreamSubscription<List<AppNotification>>? _subscription;

  Future<void> _onStarted(
    NotificationsStarted event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(NotificationsLoading());
    await _subscription?.cancel();
    _subscription = notificationRepository
        .getNotifications(event.userId)
        .listen(
          (notifications) => add(NotificationsUpdated(notifications)),
          onError: (error) => add(NotificationsFailed(error.toString())),
        );
  }

  void _onUpdated(
    NotificationsUpdated event,
    Emitter<NotificationsState> emit,
  ) {
    emit(NotificationsLoaded(event.notifications));
  }

  void _onFailed(NotificationsFailed event, Emitter<NotificationsState> emit) {
    emit(NotificationsFailure(event.message));
  }

  Future<void> _onMarkedRead(
    NotificationMarkedRead event,
    Emitter<NotificationsState> emit,
  ) async {
    final currentState = state;
    final currentNotifications = _notificationsFromState(currentState);
    if (currentNotifications == null) {
      return;
    }

    emit(NotificationsActionInProgress(currentNotifications));
    try {
      await notificationRepository.markAsRead(
        event.userId,
        event.notificationId,
      );
      emit(NotificationsLoaded(currentNotifications));
    } catch (_) {
      emit(
        NotificationsActionFailure(
          notifications: currentNotifications,
          message: 'Unable to update this notification right now.',
        ),
      );
    }
  }

  Future<void> _onMarkAllRequested(
    NotificationsMarkAllRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    final currentState = state;
    final currentNotifications = _notificationsFromState(currentState);
    if (currentNotifications == null) {
      return;
    }

    emit(NotificationsActionInProgress(currentNotifications));
    try {
      await notificationRepository.markAllAsRead(event.userId);
      emit(NotificationsLoaded(currentNotifications));
    } catch (_) {
      emit(
        NotificationsActionFailure(
          notifications: currentNotifications,
          message: 'Unable to mark notifications as read right now.',
        ),
      );
    }
  }

  List<AppNotification>? _notificationsFromState(NotificationsState state) {
    if (state is NotificationsLoaded) {
      return state.notifications;
    }
    if (state is NotificationsActionInProgress) {
      return state.notifications;
    }
    if (state is NotificationsActionFailure) {
      return state.notifications;
    }
    return null;
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
