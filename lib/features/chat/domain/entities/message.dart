import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:untitled1/core/services/supabase_service.dart';

class Message extends Equatable {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final String? imageUrl;
  final DateTime timestamp;
  final bool isRead;

  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.imageUrl,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json, String id) {
    return Message(
      id: id,
      senderId: json['senderId']?.toString() ?? '',
      receiverId: json['receiverId']?.toString() ?? '',
      text: _normalizeText(json['text']?.toString() ?? ''),
      imageUrl: json['imageUrl'],
      timestamp: SupabaseService.parseDateTime(json['timestamp']),
      isRead: json['isRead'] == true,
    );
  }

  @override
  List<Object?> get props => [
    id,
    senderId,
    receiverId,
    text,
    imageUrl,
    timestamp,
    isRead,
  ];
}

String _normalizeText(String value) {
  if (value.isEmpty) return value;
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
