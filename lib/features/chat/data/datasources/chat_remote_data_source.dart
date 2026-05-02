import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:untitled1/core/constants/supabase_constants.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/utils/text_normalizer.dart';
import 'package:untitled1/features/chat/domain/entities/conversation_summary.dart';
import 'package:untitled1/features/chat/domain/entities/message.dart';

abstract class ChatRemoteDataSource {
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

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  String _normalizeText(String value) {
    final normalized = normalizeText(value);
    if (normalized != value || value.isEmpty) {
      return normalized;
    }
    var current = value;
    for (var i = 0; i < 10; i++) {
      if (!_looksMojibake(current)) {
        break;
      }
      final repaired = _repairMojibakeOnce(current);
      if (repaired == current) {
        break;
      }
      current = repaired;
    }
    return current;
  }

  bool _looksMojibake(String value) {
    return value.contains('Ø') ||
        value.contains('Ù') ||
        value.contains('Ã') ||
        value.contains('Â') ||
        value.contains('â') ||
        value.contains('ð') ||
        value.contains('ï¿½') ||
        value.contains('\u0081') ||
        value.contains('\u008d') ||
        value.contains('\u008f') ||
        value.contains('\u0090') ||
        value.contains('\u009d');
  }

  String _repairMojibakeOnce(String value) {
    try {
      return utf8.decode(latin1.encode(value), allowMalformed: true);
    } catch (_) {
      return value;
    }
  }

  Future<String?> _resolveChatImageUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    try {
      return SupabaseService.client.storage
          .from(SupabaseBuckets.chatMedia)
          .getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteConversation(String chatId) async {
    try {
      await SupabaseService.client
          .from(SupabaseTables.messages)
          .delete()
          .eq('chatId', chatId);

      await SupabaseService.client
          .from(SupabaseTables.chats)
          .delete()
          .eq('id', chatId);
    } catch (e) {
      developer.log('Delete conversation failed', error: e);
      rethrow;
    }
  }

  @override
  Stream<List<ConversationSummary>> getConversationSummaries(String userId) {
    return SupabaseService.client
        .from(SupabaseTables.chats)
        .stream(primaryKey: ['id'])
        .asyncMap((rows) async {
          final unreadRows = await SupabaseService.client
              .from(SupabaseTables.messages)
              .select('chatId')
              .eq('receiverId', userId)
              .eq('isRead', false);
          final unreadByChatId = <String, int>{};
          for (final item in unreadRows) {
            final chatId = item['chatId']?.toString();
            if (chatId == null || chatId.isEmpty) {
              continue;
            }
            unreadByChatId[chatId] = (unreadByChatId[chatId] ?? 0) + 1;
          }

          final filteredRows =
              rows.where((data) {
                final participants = List<String>.from(
                  data['participants'] ?? const [],
                );
                return participants.contains(userId);
              }).toList()..sort((a, b) {
                final aTime = SupabaseService.parseDateTime(a['lastTimestamp']);
                final bTime = SupabaseService.parseDateTime(b['lastTimestamp']);
                return bTime.compareTo(aTime);
              });

          final otherUserIds = <String>{};
          for (final data in filteredRows) {
            final participants = List<String>.from(
              data['participants'] ?? const [],
            );
            final otherUserId = participants.firstWhere(
              (id) => id != userId,
              orElse: () => '',
            );
            if (otherUserId.isNotEmpty) {
              otherUserIds.add(otherUserId);
            }
          }

          final profilesById = <String, Map<String, dynamic>>{};
          if (otherUserIds.isNotEmpty) {
            try {
              final profiles = await SupabaseService.client
                  .from(SupabaseTables.userPublicProfiles)
                  .select(
                    'id, name, profileImageUrl, role, storeName, storeLogo',
                  )
                  .inFilter('id', otherUserIds.toList());
              for (final profile in profiles) {
                final id = profile['id']?.toString();
                if (id == null || id.isEmpty) {
                  continue;
                }
                profilesById[id] = Map<String, dynamic>.from(profile);
              }
            } catch (_) {
              // Keep conversation list available even if profile lookup fails.
            }
          }

          final summaries = <ConversationSummary>[];
          for (final data in filteredRows) {
            final participants = List<String>.from(
              data['participants'] ?? const [],
            );
            final otherUserId = participants.firstWhere(
              (id) => id != userId,
              orElse: () => '',
            );
            if (otherUserId.isEmpty) {
              continue;
            }

            final userData = profilesById[otherUserId];
            final isSeller = userData?['role'] == 'seller';
            final displayName = (isSeller && userData?['storeName'] != null)
                ? userData!['storeName'].toString()
                : userData?['name']?.toString() ?? 'User $otherUserId';
            final displayImageUrl = (isSeller && userData?['storeLogo'] != null)
                ? userData!['storeLogo'].toString()
                : userData?['profileImageUrl']?.toString();

            summaries.add(
              ConversationSummary(
                chatId: data['id'].toString(),
                otherUserId: otherUserId,
                otherUserName: _normalizeText(displayName),
                otherUserImageUrl: displayImageUrl,
                lastMessage: _normalizeText(
                  data['lastMessage']?.toString() ?? '',
                ),
                lastTimestamp: SupabaseService.parseDateTime(
                  data['lastTimestamp'],
                ),
                unreadCount: unreadByChatId[data['id']?.toString() ?? ''] ?? 0,
                otherUserRole: userData?['role']?.toString() ?? 'buyer',
                hasParticipantError: userData == null,
              ),
            );
          }

          return summaries;
        });
  }

  @override
  Future<void> markConversationRead({
    required String currentUserId,
    required String otherUserId,
  }) async {
    await SupabaseService.client.rpc(
      'mark_conversation_read',
      params: {'p_user_id': currentUserId, 'p_other_user_id': otherUserId},
    );
  }

  @override
  Stream<List<Message>> getMessages(String userId, String otherUserId) {
    final ids = [userId, otherUserId]..sort();
    final chatRoomId = ids.join('_');
    return SupabaseService.client
        .from(SupabaseTables.messages)
        .stream(primaryKey: ['id'])
        .eq('chatId', chatRoomId)
        .order('timestamp', ascending: false)
        .asyncMap((rows) async {
          final resolvedRows = await Future.wait(
            rows.map((row) async {
              final resolvedImageUrl = await _resolveChatImageUrl(
                row['imageUrl']?.toString(),
              );
              return {...row, 'imageUrl': resolvedImageUrl};
            }),
          );

          final messages = resolvedRows
              .map(
                (row) => Message.fromJson(
                  normalizeDynamicMap(Map<String, dynamic>.from(row)),
                  row['id'].toString(),
                ),
              )
              .toList();

          messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return messages;
        });
  }

  @override
  Future<void> sendMessage(Message message) async {
    try {
      final ids = [message.senderId, message.receiverId]..sort();
      final chatRoomId = ids.join('_');

      await SupabaseService.client.from(SupabaseTables.chats).upsert({
        'id': chatRoomId,
        'lastMessage': message.imageUrl != null ? 'Image' : message.text,
        'lastTimestamp': message.timestamp.toUtc().toIso8601String(),
        'participants': ids,
      });

      await SupabaseService.client.from(SupabaseTables.messages).insert({
        ...message.toJson(),
        'chatId': chatRoomId,
      });
    } catch (e) {
      developer.log('Send message failed', error: e);
      rethrow;
    }
  }

  @override
  Future<String> uploadChatImage(
    File imageFile, {
    required String currentUserId,
    required String otherUserId,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null || userId != currentUserId) {
      throw StateError('You must be signed in to upload chat media.');
    }

    final ids = [currentUserId, otherUserId]..sort();
    final chatRoomId = ids.join('_');
    await SupabaseService.client.from(SupabaseTables.chats).upsert({
      'id': chatRoomId,
      'lastMessage': '',
      'lastTimestamp': DateTime.now().toUtc().toIso8601String(),
      'participants': ids,
    });

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'chats/$chatRoomId/$userId/$fileName';
    await SupabaseService.client.storage
        .from(SupabaseBuckets.chatMedia)
        .upload(
          path,
          imageFile,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    return path;
  }
}
