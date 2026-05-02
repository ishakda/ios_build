import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/localization/localized_error_message.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_empty_state.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:untitled1/core/widgets/app_page_intro_card.dart';
import 'package:untitled1/core/widgets/app_section_header.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_state.dart';
import 'package:untitled1/features/auth/presentation/cubit/user_search_cubit.dart';
import 'package:untitled1/features/auth/presentation/cubit/user_search_state.dart';
import 'package:untitled1/features/chat/domain/entities/conversation_summary.dart';
import 'package:untitled1/features/chat/presentation/bloc/chat_list_bloc.dart';
import 'package:untitled1/features/chat/presentation/bloc/chat_list_event.dart';
import 'package:untitled1/features/chat/presentation/bloc/chat_list_state.dart';
import 'package:untitled1/features/chat/presentation/pages/chat_page.dart';
import 'package:untitled1/injection_container.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  void _showSearchDialog(BuildContext context, String currentUserId) {
    final theme = Theme.of(context);
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider(
        create: (_) => sl<UserSearchCubit>(),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outline.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppSectionHeader(
                      title: context.translate('start_conversation'),
                      subtitle: context.translate(
                        'start_conversation_subtitle',
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: context.translate('search_users_hint'),
                        prefixIcon: const Icon(AppIcons.search),
                      ),
                      onChanged: (value) {
                        context.read<UserSearchCubit>().search(value);
                      },
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: BlocBuilder<UserSearchCubit, UserSearchState>(
                        builder: (context, state) {
                          if (state is UserSearchLoading) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (state is UserSearchSuccess) {
                            if (state.users.isEmpty) {
                              return Center(
                                child: Text(
                                  context.translate('no_users_found'),
                                  style: theme.textTheme.bodyLarge,
                                ),
                              );
                            }

                            return ListView.separated(
                              controller: scrollController,
                              itemCount: state.users.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final user = state.users[index];
                                return AppSurfaceCard(
                                  radius: 20,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.primary
                                          .withValues(alpha: 0.12),
                                      backgroundImage:
                                          user.profileImageUrl != null
                                          ? NetworkImage(user.profileImageUrl!)
                                          : null,
                                      child: user.profileImageUrl == null
                                          ? const Icon(
                                              AppIcons.user,
                                              color: AppColors.primary,
                                            )
                                          : null,
                                    ),
                                    title: Text(
                                      user.name,
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    subtitle: Text(
                                      user.storeName?.trim().isNotEmpty == true
                                          ? user.storeName!
                                          : user.role == 'seller'
                                          ? context.translate('seller_store')
                                          : context.translate('buyer_account'),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatPage(
                                            currentUserId: currentUserId,
                                            otherUserId: user.id,
                                            otherUserName:
                                                user.role == 'seller' &&
                                                    user.storeName != null
                                                ? user.storeName!
                                                : user.name,
                                            otherUserImageUrl:
                                                user.role == 'seller' &&
                                                    user.storeLogo != null
                                                ? user.storeLogo
                                                : user.profileImageUrl,
                                            otherUserRole: user.role,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            );
                          }

                          if (state is UserSearchFailure) {
                            return AppEmptyState(
                              icon: AppIcons.warning,
                              title: context.translate('search_unavailable'),
                              subtitle: localizeErrorMessage(
                                context,
                                state.message,
                              ),
                              accentColor: Colors.redAccent,
                            );
                          }

                          return Center(
                            child: Text(
                              context.translate('type_to_search'),
                              style: theme.textTheme.bodyLarge,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return AppGradientScaffold(
            body: AppEmptyState(
              icon: AppIcons.messages,
              title: context.translate('sign_in_required'),
              subtitle: context.translate('sign_in_notifications_msg'),
            ),
          );
        }

        return BlocProvider(
          create: (_) =>
              sl<ChatListBloc>()..add(ChatListStarted(state.user.id)),
          child: AppGradientScaffold(
            appBar: AppBar(
              title: Text(context.translate('messages')),
              actions: [
                IconButton(
                  icon: const Icon(AppIcons.chatNew),
                  onPressed: () => _showSearchDialog(context, state.user.id),
                ),
              ],
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                  child: AppPageIntroCard(
                    title: context.translate('inbox'),
                    subtitle: context.translate('inbox_subtitle'),
                    trailing: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        AppIcons.messagesActive,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: BlocBuilder<ChatListBloc, ChatListState>(
                    builder: (context, chatState) {
                      if (chatState is ChatListInitial ||
                          chatState is ChatListLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (chatState is ChatListFailure) {
                        return AppEmptyState(
                          icon: AppIcons.warning,
                          title: context.translate('messages_unavailable'),
                          subtitle: context.translate('messages_load_error'),
                          accentColor: Colors.redAccent,
                        );
                      }

                      if (chatState is! ChatListLoaded ||
                          chatState.conversations.isEmpty) {
                        return AppEmptyState(
                          icon: AppIcons.chatEmpty,
                          title: context.translate('no_conversations_yet'),
                          subtitle: context.translate('no_conversations_msg'),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: chatState.conversations.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final conversation = chatState.conversations[index];
                          return Dismissible(
                            key: Key(conversation.chatId),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: const Icon(
                                AppIcons.trash,
                                color: Colors.white,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(context.translate('delete_chat')),
                                  content: Text(
                                    context.translate('delete_chat_confirm'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(context.translate('cancel')),
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(context.translate('delete')),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (direction) {
                              context.read<ChatListBloc>().add(
                                ChatDeleted(conversation.chatId),
                              );
                            },
                            child: _ConversationTile(
                              conversation: conversation,
                              currentUserId: state.user.id,
                              theme: theme,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.theme,
  });

  final ConversationSummary conversation;
  final String currentUserId;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      radius: 24,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: conversation.hasParticipantError
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatPage(
                      currentUserId: currentUserId,
                      otherUserId: conversation.otherUserId,
                      otherUserName: conversation.otherUserName,
                      otherUserImageUrl: conversation.otherUserImageUrl,
                      otherUserRole: conversation.otherUserRole,
                    ),
                  ),
                );
              },
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          backgroundImage: conversation.otherUserImageUrl != null
              ? NetworkImage(conversation.otherUserImageUrl!)
              : null,
          child: conversation.otherUserImageUrl == null
              ? Icon(
                  conversation.otherUserRole == 'seller'
                      ? AppIcons.seller
                      : AppIcons.user,
                  color: AppColors.primary,
                )
              : null,
        ),
        title: Text(
          conversation.otherUserName,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            conversation.hasParticipantError
                ? context.translate('recipient_error')
                : conversation.lastMessage.isEmpty
                ? context.translate('no_messages_yet')
                : conversation.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: conversation.unreadCount > 0
                  ? FontWeight.w800
                  : FontWeight.w500,
              color: conversation.unreadCount > 0
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              DateFormat('HH:mm').format(conversation.lastTimestamp),
              style: theme.textTheme.bodySmall,
            ),
            if (conversation.unreadCount > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${conversation.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
