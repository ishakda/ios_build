import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/features/admin/domain/entities/admin_product_report.dart';
import 'package:untitled1/features/admin/domain/entities/admin_refund_request.dart';
import 'package:untitled1/features/admin/domain/entities/admin_support_ticket.dart';
import 'package:untitled1/features/admin/domain/repositories/admin_repository.dart';
import 'package:untitled1/features/admin/presentation/cubit/admin_users_state.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';
import 'package:untitled1/features/checkout/domain/entities/order.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';

class AdminUsersCubit extends Cubit<AdminUsersState> {
  AdminUsersCubit({required this.adminRepository})
    : super(const AdminUsersState());

  final AdminRepository adminRepository;
  StreamSubscription<List<User>>? _usersSubscription;
  StreamSubscription<List<Product>>? _productsSubscription;
  StreamSubscription<List<Order>>? _ordersSubscription;
  StreamSubscription<List<AdminSupportTicket>>? _ticketsSubscription;
  StreamSubscription<List<AdminProductReport>>? _reportsSubscription;
  StreamSubscription<List<AdminRefundRequest>>? _refundsSubscription;

  Future<void> load() async {
    emit(
      state.copyWith(
        isLoading: true,
        clearErrorMessage: true,
        clearActionMessage: true,
      ),
    );

    await _usersSubscription?.cancel();
    await _productsSubscription?.cancel();
    await _ordersSubscription?.cancel();
    await _ticketsSubscription?.cancel();
    await _reportsSubscription?.cancel();
    await _refundsSubscription?.cancel();

    _usersSubscription = adminRepository.watchUsers().listen(
      (users) => emit(
        state.copyWith(isLoading: false, users: users, clearErrorMessage: true),
      ),
      onError: (_) => _emitLoadError('Unable to load admin users right now.'),
    );

    _productsSubscription = adminRepository.watchProducts().listen(
      (products) => emit(
        state.copyWith(
          isLoading: false,
          products: products,
          clearErrorMessage: true,
        ),
      ),
      onError: (_) => _emitLoadError('Unable to load products right now.'),
    );

    _ordersSubscription = adminRepository.watchOrders().listen(
      (orders) => emit(
        state.copyWith(
          isLoading: false,
          orders: orders,
          clearErrorMessage: true,
        ),
      ),
      onError: (_) => _emitLoadError('Unable to load orders right now.'),
    );

    _ticketsSubscription = adminRepository.watchSupportTickets().listen(
      (tickets) => emit(
        state.copyWith(
          isLoading: false,
          supportTickets: tickets,
          clearErrorMessage: true,
        ),
      ),
      onError: (_) =>
          _emitLoadError('Unable to load support tickets right now.'),
    );

    _reportsSubscription = adminRepository.watchProductReports().listen(
      (reports) => emit(
        state.copyWith(
          isLoading: false,
          productReports: reports,
          clearErrorMessage: true,
        ),
      ),
      onError: (_) =>
          _emitLoadError('Unable to load product reports right now.'),
    );

    _refundsSubscription = adminRepository.watchRefundRequests().listen(
      (refunds) => emit(
        state.copyWith(
          isLoading: false,
          refundRequests: refunds,
          clearErrorMessage: true,
        ),
      ),
      onError: (_) =>
          _emitLoadError('Unable to load refund requests right now.'),
    );
  }

  void setQuery(String query) {
    emit(state.copyWith(query: query));
  }

  void setFilter(AdminUserFilter filter) {
    emit(state.copyWith(filter: filter));
  }

  Future<void> approveSeller(User user) async {
    await _runAction(
      user.id,
      () => adminRepository.setSellerApproval(
        userId: user.id,
        isApproved: true,
        isVerifiedSeller: user.isVerifiedSeller,
        verificationLevel: user.verificationLevel == 'none'
            ? 'basic'
            : user.verificationLevel,
        trustScore: user.trustScore <= 0 ? 10 : user.trustScore,
      ),
      successMessage: 'Seller approved.',
    );
  }

  Future<void> revokeSellerApproval(User user) async {
    await _runAction(
      user.id,
      () => adminRepository.setSellerApproval(
        userId: user.id,
        isApproved: false,
        isVerifiedSeller: false,
        verificationLevel: 'none',
        trustScore: 0,
      ),
      successMessage: 'Seller approval removed.',
    );
  }

  Future<void> setCodBlock(User user, bool isBlocked) async {
    await _runAction(
      user.id,
      () => adminRepository.setUserBan(
        userId: user.id,
        isBanned: user.isBanned,
        isCodBlocked: isBlocked,
      ),
      successMessage: isBlocked
          ? 'COD blocked for user.'
          : 'COD block removed.',
    );
  }

  Future<void> banUser(User user, {String? reason}) async {
    await _runAction(
      user.id,
      () => adminRepository.setUserBan(
        userId: user.id,
        isBanned: true,
        reason: reason,
        isCodBlocked: true,
      ),
      successMessage: 'User suspended.',
    );
  }

  Future<void> unbanUser(User user) async {
    await _runAction(
      user.id,
      () => adminRepository.setUserBan(
        userId: user.id,
        isBanned: false,
        isCodBlocked: false,
      ),
      successMessage: 'User suspension removed.',
    );
  }

  Future<void> updateTicket(
    AdminSupportTicket ticket, {
    required String status,
    String? adminNote,
  }) async {
    await _runAction(
      ticket.id,
      () => adminRepository.updateSupportTicketStatus(
        ticketId: ticket.id,
        status: status,
        adminNote: adminNote,
      ),
      successMessage: 'Ticket updated.',
    );
  }

  Future<void> updateReport(
    AdminProductReport report, {
    required String status,
    String? adminNote,
  }) async {
    await _runAction(
      report.id,
      () => adminRepository.updateProductReportStatus(
        reportId: report.id,
        status: status,
        adminNote: adminNote,
      ),
      successMessage: 'Report updated.',
    );
  }

  Future<void> updateRefundRequest(
    AdminRefundRequest request, {
    required String status,
    String? adminNote,
  }) async {
    await _runAction(
      request.id,
      () => adminRepository.updateRefundRequestStatus(
        requestId: request.id,
        status: status,
        adminNote: adminNote,
      ),
      successMessage: 'Refund request updated.',
    );
  }

  Future<void> deleteProduct(Product product) async {
    await _runAction(
      product.id,
      () => adminRepository.deleteProduct(product.id),
      successMessage: 'Product deleted.',
    );
  }

  void _emitLoadError(String message) {
    emit(state.copyWith(isLoading: false, errorMessage: message));
  }

  Future<void> _runAction(
    String actionId,
    Future<Object?> Function() action, {
    String? successMessage,
  }) async {
    emit(
      state.copyWith(
        actionUserId: actionId,
        clearErrorMessage: true,
        clearActionMessage: true,
      ),
    );

    try {
      await action();
      emit(
        state.copyWith(actionMessage: successMessage, clearActionUserId: true),
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString(), clearActionUserId: true));
    }
  }

  @override
  Future<void> close() async {
    await _usersSubscription?.cancel();
    await _productsSubscription?.cancel();
    await _ordersSubscription?.cancel();
    await _ticketsSubscription?.cancel();
    await _reportsSubscription?.cancel();
    await _refundsSubscription?.cancel();
    return super.close();
  }
}
