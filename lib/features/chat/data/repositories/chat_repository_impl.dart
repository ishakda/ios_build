import 'dart:io';
import 'package:untitled1/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:untitled1/features/chat/domain/entities/conversation_summary.dart';
import 'package:untitled1/features/chat/domain/entities/message.dart';
import 'package:untitled1/features/chat/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remoteDataSource;

  ChatRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<ConversationSummary>> getConversationSummaries(String userId) {
    return remoteDataSource.getConversationSummaries(userId);
  }

  @override
  Stream<List<Message>> getMessages(String userId, String otherUserId) {
    return remoteDataSource.getMessages(userId, otherUserId);
  }

  @override
  Future<void> sendMessage(Message message) async {
    return await remoteDataSource.sendMessage(message);
  }

  @override
  Future<void> markConversationRead({
    required String currentUserId,
    required String otherUserId,
  }) async {
    return await remoteDataSource.markConversationRead(
      currentUserId: currentUserId,
      otherUserId: otherUserId,
    );
  }

  @override
  Future<void> deleteConversation(String chatId) async {
    return await remoteDataSource.deleteConversation(chatId);
  }

  @override
  Future<String> uploadChatImage(
    File imageFile, {
    required String currentUserId,
    required String otherUserId,
  }) async {
    return await remoteDataSource.uploadChatImage(
      imageFile,
      currentUserId: currentUserId,
      otherUserId: otherUserId,
    );
  }
}
