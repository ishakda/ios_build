import 'package:equatable/equatable.dart';
import 'package:untitled1/features/chat/domain/entities/conversation_summary.dart';

abstract class ChatListEvent extends Equatable {
  const ChatListEvent();

  @override
  List<Object?> get props => [];
}

class ChatListStarted extends ChatListEvent {
  const ChatListStarted(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}

class ChatListUpdated extends ChatListEvent {
  const ChatListUpdated(this.conversations);

  final List<ConversationSummary> conversations;

  @override
  List<Object?> get props => [conversations];
}

class ChatListFailed extends ChatListEvent {
  const ChatListFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class ChatDeleted extends ChatListEvent {
  const ChatDeleted(this.chatId);

  final String chatId;

  @override
  List<Object?> get props => [chatId];
}
