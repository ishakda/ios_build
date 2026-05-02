import 'package:equatable/equatable.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/utils/text_normalizer.dart';

class AdminProductReport extends Equatable {
  const AdminProductReport({
    required this.id,
    required this.productId,
    required this.reporterUserId,
    this.sellerId,
    required this.reason,
    this.details,
    required this.status,
    this.adminNote,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String productId;
  final String reporterUserId;
  final String? sellerId;
  final String reason;
  final String? details;
  final String status;
  final String? adminNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AdminProductReport.fromMap(Map<String, dynamic> map) {
    return AdminProductReport(
      id: map['id'].toString(),
      productId: map['productId']?.toString() ?? '',
      reporterUserId: map['reporterUserId']?.toString() ?? '',
      sellerId: map['sellerId']?.toString(),
      reason: normalizeText(map['reason']?.toString() ?? ''),
      details: normalizeNullableText(map['details']?.toString()),
      status: map['status']?.toString() ?? 'open',
      adminNote: normalizeNullableText(map['adminNote']?.toString()),
      createdAt: SupabaseService.parseDateTime(map['createdAt']),
      updatedAt: SupabaseService.parseDateTime(map['updatedAt']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    productId,
    reporterUserId,
    sellerId,
    reason,
    details,
    status,
    adminNote,
    createdAt,
    updatedAt,
  ];
}
