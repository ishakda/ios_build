import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:untitled1/features/notifications/domain/entities/app_notification.dart';
import 'package:untitled1/features/notifications/domain/repositories/notification_repository.dart';
import 'package:untitled1/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:untitled1/features/notifications/presentation/bloc/notifications_event.dart';
import 'package:untitled1/features/notifications/presentation/bloc/notifications_state.dart';

class _FakeNotificationRepository implements NotificationRepository {
  _FakeNotificationRepository({
    this.stream,
    this.markAsReadError,
    this.markAllError,
  });

  final Stream<List<AppNotification>>? stream;
  final Exception? markAsReadError;
  final Exception? markAllError;

  @override
  Stream<List<AppNotification>> getNotifications(String userId) {
    return stream ?? const Stream.empty();
  }

  @override
  Future<void> markAsRead(String userId, String notificationId) async {
    if (markAsReadError != null) {
      throw markAsReadError!;
    }
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    if (markAllError != null) {
      throw markAllError!;
    }
  }
}

class _TestNotificationsBloc extends NotificationsBloc {
  _TestNotificationsBloc({required super.notificationRepository});

  void seed(NotificationsState state) {
    emit(state);
  }
}

void main() {
  final notifications = [
    AppNotification(
      id: 'n1',
      title: 'Order Shipped',
      body: 'Your order is on the way.',
      timestamp: DateTime(2026, 4, 26, 12),
      type: 'order',
    ),
  ];

  test('NotificationsStarted emits loading then loaded', () async {
    final controller = StreamController<List<AppNotification>>();
    final bloc = NotificationsBloc(
      notificationRepository: _FakeNotificationRepository(
        stream: controller.stream,
      ),
    );

    final expectation = expectLater(
      bloc.stream,
      emitsInOrder([
        isA<NotificationsLoading>(),
        isA<NotificationsLoaded>().having(
          (state) => state.notifications.first.id,
          'first notification id',
          'n1',
        ),
      ]),
    );

    bloc.add(const NotificationsStarted('u1'));
    controller.add(notifications);

    await expectation;
    await controller.close();
    await bloc.close();
  });

  test(
    'NotificationMarkedRead emits action failure when repository throws',
    () async {
      final bloc = _TestNotificationsBloc(
        notificationRepository: _FakeNotificationRepository(
          markAsReadError: Exception('write failed'),
        ),
      );

      bloc.seed(NotificationsLoaded(notifications));
      bloc.add(
        const NotificationMarkedRead(userId: 'u1', notificationId: 'n1'),
      );

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<NotificationsActionInProgress>(),
          isA<NotificationsActionFailure>()
              .having((state) => state.notifications.length, 'count', 1)
              .having(
                (state) => state.message,
                'message',
                'Unable to update this notification right now.',
              ),
        ]),
      );

      await bloc.close();
    },
  );

  test(
    'NotificationsMarkAllRequested emits action failure when repository throws',
    () async {
      final bloc = _TestNotificationsBloc(
        notificationRepository: _FakeNotificationRepository(
          markAllError: Exception('write failed'),
        ),
      );

      bloc.seed(NotificationsLoaded(notifications));
      bloc.add(const NotificationsMarkAllRequested('u1'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<NotificationsActionInProgress>(),
          isA<NotificationsActionFailure>().having(
            (state) => state.message,
            'message',
            'Unable to mark notifications as read right now.',
          ),
        ]),
      );

      await bloc.close();
    },
  );
}
