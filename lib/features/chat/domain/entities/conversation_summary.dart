import 'package:equatable/equatable.dart';

class ConversationSummary extends Equatable {
  const ConversationSummary({
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserImageUrl,
    required this.lastMessage,
    required this.lastTimestamp,
    this.unreadCount = 0,
    this.hasParticipantError = false,
    this.otherUserRole = 'buyer',
  });

  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserImageUrl;
  final String lastMessage;
  final DateTime lastTimestamp;
  final int unreadCount;
  final bool hasParticipantError;
  final String otherUserRole;

  @override
  List<Object?> get props => [
    chatId,
    otherUserId,
    otherUserName,
    otherUserImageUrl,
    lastMessage,
    lastTimestamp,
    unreadCount,
    hasParticipantError,
    otherUserRole,
  ];
}
