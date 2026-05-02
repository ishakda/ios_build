import 'dart:io';
import 'package:untitled1/features/chat/domain/entities/conversation_summary.dart';
import 'package:untitled1/features/chat/domain/entities/message.dart';

abstract class ChatRepository {
  Stream<List<ConversationSummary>> getConversationSummaries(String userId);
  Stream<List<Message>> getMessages(String userId, String otherUserId);
  Future<void> sendMessage(Message message);
  Future<void> markConversationRead({
    required String currentUserId,
    required String otherUserId,
  });
  Future<void> deleteConversation(String chatId);
  Future<String> uploadChatImage(
    File imageFile, {
    required String currentUserId,
    required String otherUserId,
  });
}
