import 'package:equatable/equatable.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/utils/text_normalizer.dart';

class AdminRefundRequest extends Equatable {
  const AdminRefundRequest({
    required this.id,
    required this.orderId,
    required this.buyerId,
    required this.reason,
    this.details,
    required this.status,
    this.adminNote,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String orderId;
  final String buyerId;
  final String reason;
  final String? details;
  final String status;
  final String? adminNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AdminRefundRequest.fromMap(Map<String, dynamic> map) {
    return AdminRefundRequest(
      id: map['id'].toString(),
      orderId: map['orderId']?.toString() ?? '',
      buyerId: map['buyerId']?.toString() ?? '',
      reason: normalizeText(map['reason']?.toString() ?? ''),
      details: normalizeNullableText(map['details']?.toString()),
      status: map['status']?.toString() ?? 'pending',
      adminNote: normalizeNullableText(map['adminNote']?.toString()),
      createdAt: SupabaseService.parseDateTime(map['createdAt']),
      updatedAt: SupabaseService.parseDateTime(map['updatedAt']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    orderId,
    buyerId,
    reason,
    details,
    status,
    adminNote,
    createdAt,
    updatedAt,
  ];
}
