import 'package:equatable/equatable.dart';
import 'package:untitled1/features/chat/domain/entities/conversation_summary.dart';

abstract class ChatListState extends Equatable {
  const ChatListState();

  @override
  List<Object?> get props => [];
}

class ChatListInitial extends ChatListState {}

class ChatListLoading extends ChatListState {}

class ChatListLoaded extends ChatListState {
  const ChatListLoaded(this.conversations);

  final List<ConversationSummary> conversations;

  @override
  List<Object?> get props => [conversations];
}

class ChatListFailure extends ChatListState {
  const ChatListFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
