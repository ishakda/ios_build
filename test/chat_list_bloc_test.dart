import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:untitled1/features/chat/domain/entities/conversation_summary.dart';
import 'package:untitled1/features/chat/domain/entities/message.dart';
import 'package:untitled1/features/chat/domain/repositories/chat_repository.dart';
import 'package:untitled1/features/chat/presentation/bloc/chat_list_bloc.dart';
import 'package:untitled1/features/chat/presentation/bloc/chat_list_event.dart';
import 'package:untitled1/features/chat/presentation/bloc/chat_list_state.dart';

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({this.conversationStream});

  final Stream<List<ConversationSummary>>? conversationStream;

  @override
  Stream<List<ConversationSummary>> getConversationSummaries(String userId) {
    return conversationStream ?? const Stream.empty();
  }

  @override
  Stream<List<Message>> getMessages(String userId, String otherUserId) {
    return const Stream.empty();
  }

  @override
  Future<void> sendMessage(Message message) async {}

  @override
  Future<void> markConversationRead({
    required String currentUserId,
    required String otherUserId,
  }) async {}

  @override
  Future<void> deleteConversation(String chatId) async {}

  @override
  Future<String> uploadChatImage(
    File imageFile, {
    required String currentUserId,
    required String otherUserId,
  }) async {
    return 'fake_url';
  }
}

void main() {
  final conversations = [
    ConversationSummary(
      chatId: 'c1',
      otherUserId: 'u2',
      otherUserName: 'Seller One',
      lastMessage: 'Hello',
      lastTimestamp: DateTime(2026, 4, 26, 13),
    ),
  ];

  test('ChatListStarted emits loading then loaded', () async {
    final controller = StreamController<List<ConversationSummary>>();
    final bloc = ChatListBloc(
      chatRepository: _FakeChatRepository(
        conversationStream: controller.stream,
      ),
    );

    final expectation = expectLater(
      bloc.stream,
      emitsInOrder([
        isA<ChatListLoading>(),
        isA<ChatListLoaded>().having(
          (state) => state.conversations.first.otherUserId,
          'other user id',
          'u2',
        ),
      ]),
    );

    bloc.add(const ChatListStarted('u1'));
    controller.add(conversations);

    await expectation;
    await controller.close();
    await bloc.close();
  });

  test('stream errors emit ChatListFailure', () async {
    final controller = StreamController<List<ConversationSummary>>();
    final bloc = ChatListBloc(
      chatRepository: _FakeChatRepository(
        conversationStream: controller.stream,
      ),
    );

    final expectation = expectLater(
      bloc.stream,
      emitsInOrder([
        isA<ChatListLoading>(),
        isA<ChatListFailure>().having(
          (state) => state.message,
          'message',
          contains('stream failed'),
        ),
      ]),
    );

    bloc.add(const ChatListStarted('u1'));
    controller.addError(Exception('stream failed'));

    await expectation;
    await controller.close();
    await bloc.close();
  });
}
