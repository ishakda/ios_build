import 'package:equatable/equatable.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/utils/text_normalizer.dart';

class AdminSupportTicket extends Equatable {
  const AdminSupportTicket({
    required this.id,
    required this.userId,
    required this.subject,
    required this.message,
    required this.contactMethod,
    this.contactValue,
    required this.status,
    this.adminNote,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String subject;
  final String message;
  final String contactMethod;
  final String? contactValue;
  final String status;
  final String? adminNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AdminSupportTicket.fromMap(Map<String, dynamic> map) {
    return AdminSupportTicket(
      id: map['id'].toString(),
      userId: map['userId']?.toString() ?? '',
      subject: normalizeText(map['subject']?.toString() ?? ''),
      message: normalizeText(map['message']?.toString() ?? ''),
      contactMethod: map['contactMethod']?.toString() ?? 'in_app',
      contactValue: normalizeNullableText(map['contactValue']?.toString()),
      status: map['status']?.toString() ?? 'open',
      adminNote: normalizeNullableText(map['adminNote']?.toString()),
      createdAt: SupabaseService.parseDateTime(map['createdAt']),
      updatedAt: SupabaseService.parseDateTime(map['updatedAt']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    subject,
    message,
    contactMethod,
    contactValue,
    status,
    adminNote,
    createdAt,
    updatedAt,
  ];
}
