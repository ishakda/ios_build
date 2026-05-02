import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/localization/localized_error_message.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_empty_state.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:untitled1/core/widgets/app_page_intro_card.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_state.dart';
import 'package:untitled1/features/notifications/domain/entities/app_notification.dart';
import 'package:untitled1/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:untitled1/features/notifications/presentation/bloc/notifications_event.dart';
import 'package:untitled1/features/notifications/presentation/bloc/notifications_state.dart';
import 'package:untitled1/injection_container.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return AppGradientScaffold(
            body: AppEmptyState(
              icon: AppIcons.notifications,
              title: context.translate('sign_in_required'),
              subtitle: context.translate('sign_in_notifications_msg'),
            ),
          );
        }

        return BlocProvider(
          create: (_) =>
              sl<NotificationsBloc>()..add(NotificationsStarted(state.user.id)),
          child: _NotificationsView(userId: state.user.id),
        );
      },
    );
  }
}

class _NotificationsView extends StatefulWidget {
  const _NotificationsView({required this.userId});

  final String userId;

  @override
  State<_NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<_NotificationsView> {
  String? _lastActionError;

  @override
  Widget build(BuildContext context) {
    return BlocListener<NotificationsBloc, NotificationsState>(
      listener: (context, state) {
        if (state is NotificationsActionFailure &&
            state.message != _lastActionError) {
          _lastActionError = state.message;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizeErrorMessage(context, state.message)),
              backgroundColor: Colors.redAccent,
            ),
          );
        } else if (state is NotificationsLoaded) {
          _lastActionError = null;
        }
      },
      child: AppGradientScaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: AppPageIntroCard(
                  title: context.translate('notifications'),
                  subtitle: context.translate('notifications_center_subtitle'),
                  trailing: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      AppIcons.notificationsActive,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: BlocBuilder<NotificationsBloc, NotificationsState>(
                  builder: (context, state) {
                    if (state is NotificationsInitial ||
                        state is NotificationsLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state is NotificationsFailure) {
                      return AppEmptyState(
                        icon: AppIcons.warning,
                        title: context.translate('notifications_unavailable'),
                        subtitle: context.translate('notifications_load_error'),
                        accentColor: Colors.redAccent,
                        actionLabel: context.translate('go_back'),
                        onAction: () => Navigator.pop(context),
                      );
                    }

                    final notifications = _notificationsFromState(state);
                    if (notifications == null || notifications.isEmpty) {
                      return _buildEmptyState(context);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final item = notifications[index];
                        return _NotificationTile(
                              notification: item,
                              onTap: () =>
                                  context.read<NotificationsBloc>().add(
                                    NotificationMarkedRead(
                                      userId: widget.userId,
                                      notificationId: item.id,
                                    ),
                                  ),
                            )
                            .animate()
                            .fadeIn(delay: (index * 100).ms)
                            .slideX(begin: 0.1, end: 0);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CircleActionButton(
            icon: AppIcons.back,
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            context.translate('notifications'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          TextButton(
            onPressed: () => context.read<NotificationsBloc>().add(
              NotificationsMarkAllRequested(widget.userId),
            ),
            child: Text(
              context.translate('mark_all_read'),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AppEmptyState(
      icon: AppIcons.bellRinging,
      title: context.translate('no_notifications'),
      subtitle: context.translate('no_notifications_msg'),
    ).animate().fadeIn();
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
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AppSurfaceCard(
        margin: const EdgeInsets.only(bottom: 12),
        radius: 22,
        borderColor: !notification.isRead
            ? AppColors.primary.withValues(alpha: 0.14)
            : theme.colorScheme.outline.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: _getIconColor(
                    notification.type,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  _getIcon(notification.type),
                  color: _getIconColor(notification.type),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: !notification.isRead
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            height: 8,
                            width: 8,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: !notification.isRead
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatTime(context, notification.timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(BuildContext context, DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${context.translate('mins_ago')}';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} ${context.translate('hours_ago')}';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} ${context.translate('days_ago')}';
    }
    return DateFormat('MMM dd, yyyy').format(timestamp);
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'order':
        return AppIcons.shipping;
      case 'promo':
        return AppIcons.offer;
      case 'wallet':
        return AppIcons.wallet;
      default:
        return AppIcons.notificationsActive;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'order':
        return Colors.blue;
      case 'promo':
        return AppColors.accent;
      case 'wallet':
        return Colors.green;
      default:
        return AppColors.primary;
    }
  }
}

class _CircleActionButton extends StatefulWidget {
  const _CircleActionButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  State<_CircleActionButton> createState() => _CircleActionButtonState();
}

class _CircleActionButtonState extends State<_CircleActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: 100.ms,
        transform: Matrix4.diagonal3Values(
          _isPressed ? 0.9 : 1.0,
          _isPressed ? 0.9 : 1.0,
          1.0,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            widget.icon,
            color: theme.colorScheme.onSurface,
            size: 22,
          ),
        ),
      ),
    );
  }
}
