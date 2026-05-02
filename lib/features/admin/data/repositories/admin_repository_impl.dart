import 'package:untitled1/features/admin/domain/entities/admin_product_report.dart';
import 'package:untitled1/features/admin/domain/entities/admin_refund_request.dart';
import 'package:untitled1/features/admin/domain/entities/admin_support_ticket.dart';
import 'package:untitled1/core/constants/supabase_constants.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/utils/text_normalizer.dart';
import 'package:untitled1/features/admin/domain/repositories/admin_repository.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';
import 'package:untitled1/features/checkout/domain/entities/order.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';

class AdminRepositoryImpl implements AdminRepository {
  User _mapUser(dynamic response) {
    if (response is Map) {
      return User.fromMap(Map<String, dynamic>.from(response));
    }
    if (response is List && response.isNotEmpty && response.first is Map) {
      return User.fromMap(Map<String, dynamic>.from(response.first as Map));
    }
    throw Exception('Unexpected admin RPC response');
  }

  @override
  Stream<List<User>> watchUsers() {
    return SupabaseService.client
        .from(SupabaseTables.users)
        .stream(primaryKey: ['id'])
        .map((rows) {
          final users = rows.map(User.fromMap).toList();
          users.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          return users;
        });
  }

  @override
  Stream<List<Product>> watchProducts() {
    return SupabaseService.client
        .from(SupabaseTables.products)
        .stream(primaryKey: ['id'])
        .map((rows) {
          final products = <Product>[];
          for (final row in rows) {
            try {
              products.add(
                Product.fromJson(normalizeDynamicMap(Map<String, dynamic>.from(row))),
              );
            } catch (_) {
              // Skip malformed rows to keep the admin feed available.
            }
          }
          return products;
        });
  }

  @override
  Stream<List<Order>> watchOrders() {
    return SupabaseService.client
        .from(SupabaseTables.orders)
        .stream(primaryKey: ['id'])
        .map((rows) => rows.map(Order.fromJson).toList());
  }

  @override
  Stream<List<AdminSupportTicket>> watchSupportTickets() {
    return SupabaseService.client
        .from(SupabaseTables.supportTickets)
        .stream(primaryKey: ['id'])
        .map((rows) => rows.map(AdminSupportTicket.fromMap).toList());
  }

  @override
  Stream<List<AdminProductReport>> watchProductReports() {
    return SupabaseService.client
        .from(SupabaseTables.productReports)
        .stream(primaryKey: ['id'])
        .map((rows) => rows.map(AdminProductReport.fromMap).toList());
  }

  @override
  Stream<List<AdminRefundRequest>> watchRefundRequests() {
    return SupabaseService.client
        .from(SupabaseTables.refundRequests)
        .stream(primaryKey: ['id'])
        .map((rows) => rows.map(AdminRefundRequest.fromMap).toList());
  }

  @override
  Future<User> setSellerApproval({
    required String userId,
    required bool isApproved,
    bool? isVerifiedSeller,
    String? verificationLevel,
    double? trustScore,
  }) async {
    final response = await SupabaseService.client.rpc(
      'admin_set_seller_approval',
      params: {
        'p_target_user_id': userId,
        'p_is_approved': isApproved,
        'p_is_verified_seller': isVerifiedSeller,
        'p_verification_level': verificationLevel,
        'p_trust_score': trustScore,
      },
    );
    return _mapUser(response);
  }

  @override
  Future<User> setUserBan({
    required String userId,
    required bool isBanned,
    String? reason,
    bool? isCodBlocked,
  }) async {
    final response = await SupabaseService.client.rpc(
      'admin_set_user_ban',
      params: {
        'p_target_user_id': userId,
        'p_is_banned': isBanned,
        'p_reason': reason,
        'p_is_cod_blocked': isCodBlocked,
      },
    );
    return _mapUser(response);
  }

  @override
  Future<void> updateSupportTicketStatus({
    required String ticketId,
    required String status,
    String? adminNote,
  }) async {
    await SupabaseService.client.rpc(
      'admin_update_support_ticket',
      params: {
        'p_ticket_id': ticketId,
        'p_status': status,
        'p_admin_note': adminNote,
      },
    );
  }

  @override
  Future<void> updateProductReportStatus({
    required String reportId,
    required String status,
    String? adminNote,
  }) async {
    await SupabaseService.client.rpc(
      'admin_update_product_report',
      params: {
        'p_report_id': reportId,
        'p_status': status,
        'p_admin_note': adminNote,
      },
    );
  }

  @override
  Future<void> updateRefundRequestStatus({
    required String requestId,
    required String status,
    String? adminNote,
  }) async {
    await SupabaseService.client.rpc(
      'admin_update_refund_request',
      params: {
        'p_request_id': requestId,
        'p_status': status,
        'p_admin_note': adminNote,
      },
    );
  }

  @override
  Future<void> deleteProduct(String productId) async {
    await SupabaseService.client
        .from(SupabaseTables.products)
        .delete()
        .eq('id', productId);
  }
}
