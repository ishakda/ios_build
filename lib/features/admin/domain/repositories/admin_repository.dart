import 'package:untitled1/features/admin/domain/entities/admin_product_report.dart';
import 'package:untitled1/features/admin/domain/entities/admin_refund_request.dart';
import 'package:untitled1/features/admin/domain/entities/admin_support_ticket.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';
import 'package:untitled1/features/checkout/domain/entities/order.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';

abstract class AdminRepository {
  Stream<List<User>> watchUsers();
  Stream<List<Product>> watchProducts();
  Stream<List<Order>> watchOrders();
  Stream<List<AdminSupportTicket>> watchSupportTickets();
  Stream<List<AdminProductReport>> watchProductReports();
  Stream<List<AdminRefundRequest>> watchRefundRequests();

  Future<User> setSellerApproval({
    required String userId,
    required bool isApproved,
    bool? isVerifiedSeller,
    String? verificationLevel,
    double? trustScore,
  });

  Future<User> setUserBan({
    required String userId,
    required bool isBanned,
    String? reason,
    bool? isCodBlocked,
  });

  Future<void> updateSupportTicketStatus({
    required String ticketId,
    required String status,
    String? adminNote,
  });

  Future<void> updateProductReportStatus({
    required String reportId,
    required String status,
    String? adminNote,
  });

  Future<void> updateRefundRequestStatus({
    required String requestId,
    required String status,
    String? adminNote,
  });

  Future<void> deleteProduct(String productId);
}
