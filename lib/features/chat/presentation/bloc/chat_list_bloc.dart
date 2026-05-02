import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/features/chat/domain/entities/conversation_summary.dart';
import 'package:untitled1/features/chat/domain/repositories/chat_repository.dart';
import 'package:untitled1/features/chat/presentation/bloc/chat_list_event.dart';
import 'package:untitled1/features/chat/presentation/bloc/chat_list_state.dart';

class ChatListBloc extends Bloc<ChatListEvent, ChatListState> {
  ChatListBloc({required this.chatRepository}) : super(ChatListInitial()) {
    on<ChatListStarted>(_onStarted);
    on<ChatListUpdated>(_onUpdated);
    on<ChatListFailed>(_onFailed);
    on<ChatDeleted>(_onDeleted);
  }

  final ChatRepository chatRepository;
  StreamSubscription<List<ConversationSummary>>? _subscription;

  Future<void> _onDeleted(ChatDeleted event, Emitter<ChatListState> emit) async {
    try {
      await chatRepository.deleteConversation(event.chatId);
    } catch (e) {
      add(ChatListFailed(e.toString()));
    }
  }

  Future<void> _onStarted(
    ChatListStarted event,
    Emitter<ChatListState> emit,
  ) async {
    emit(ChatListLoading());
    await _subscription?.cancel();
    _subscription = chatRepository
        .getConversationSummaries(event.userId)
        .listen(
          (conversations) => add(ChatListUpdated(conversations)),
          onError: (error) => add(ChatListFailed(error.toString())),
        );
  }

  void _onUpdated(ChatListUpdated event, Emitter<ChatListState> emit) {
    emit(ChatListLoaded(event.conversations));
  }

  void _onFailed(ChatListFailed event, Emitter<ChatListState> emit) {
    emit(ChatListFailure(event.message));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
