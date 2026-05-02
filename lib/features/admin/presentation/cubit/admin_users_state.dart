import 'package:equatable/equatable.dart';
import 'package:untitled1/features/admin/domain/entities/admin_product_report.dart';
import 'package:untitled1/features/admin/domain/entities/admin_refund_request.dart';
import 'package:untitled1/features/admin/domain/entities/admin_support_ticket.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';
import 'package:untitled1/features/checkout/domain/entities/order.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';

enum AdminUserFilter { all, pendingSellers, sellers, buyers, banned }

class AdminUsersState extends Equatable {
  const AdminUsersState({
    this.isLoading = true,
    this.users = const [],
    this.products = const [],
    this.orders = const [],
    this.supportTickets = const [],
    this.productReports = const [],
    this.refundRequests = const [],
    this.query = '',
    this.filter = AdminUserFilter.all,
    this.errorMessage,
    this.actionMessage,
    this.actionUserId,
  });

  final bool isLoading;
  final List<User> users;
  final List<Product> products;
  final List<Order> orders;
  final List<AdminSupportTicket> supportTickets;
  final List<AdminProductReport> productReports;
  final List<AdminRefundRequest> refundRequests;
  final String query;
  final AdminUserFilter filter;
  final String? errorMessage;
  final String? actionMessage;
  final String? actionUserId;

  List<User> get visibleUsers {
    final normalizedQuery = query.trim().toLowerCase();
    return users.where((user) {
      final matchesFilter = switch (filter) {
        AdminUserFilter.all => true,
        AdminUserFilter.pendingSellers =>
          user.isSeller && !user.isSellerApproved && !user.isBanned,
        AdminUserFilter.sellers => user.isSeller,
        AdminUserFilter.buyers => user.role == 'buyer',
        AdminUserFilter.banned => user.isBanned,
      };

      if (!matchesFilter) {
        return false;
      }

      if (normalizedQuery.isEmpty) {
        return true;
      }

      final haystack = [
        user.name,
        user.email,
        user.storeName,
        user.phoneNumber,
        user.role,
      ].whereType<String>().join(' ').toLowerCase();

      return haystack.contains(normalizedQuery);
    }).toList();
  }

  List<AdminSupportTicket> get sortedTickets {
    final items = [...supportTickets];
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  List<AdminProductReport> get sortedReports {
    final items = [...productReports];
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  List<AdminRefundRequest> get sortedRefundRequests {
    final items = [...refundRequests];
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  int get pendingSellerCount => users
      .where(
        (user) => user.isSeller && !user.isSellerApproved && !user.isBanned,
      )
      .length;

  int get totalUserCount => users.length;

  int get sellerCount => users.where((user) => user.isSeller).length;

  int get approvedSellerCount =>
      users.where((user) => user.canSellProducts).length;

  int get bannedCount => users.where((user) => user.isBanned).length;

  int get codBlockedCount => users.where((user) => user.isCodBlocked).length;

  int get buyerCount => users.where((user) => user.role == 'buyer').length;

  int get openTicketCount => supportTickets
      .where(
        (ticket) => ticket.status == 'open' || ticket.status == 'in_progress',
      )
      .length;

  int get openReportCount => productReports
      .where(
        (report) => report.status == 'open' || report.status == 'reviewing',
      )
      .length;

  int get pendingRefundCount =>
      refundRequests.where((request) => request.status == 'pending').length;

  int get openCaseCount =>
      openTicketCount + openReportCount + pendingRefundCount;

  int get cancelledOrderCount =>
      orders.where((order) => order.status.toLowerCase() == 'cancelled').length;

  int get deliveredOrderCount => orders
      .where(
        (order) =>
            order.status.toLowerCase() == 'delivered' ||
            order.status.toLowerCase() == 'received',
      )
      .length;

  List<MapEntry<String, int>> get cancelledOrdersByBuyer {
    final counts = <String, int>{};
    for (final order in orders) {
      if (order.status.toLowerCase() != 'cancelled') {
        continue;
      }
      counts.update(order.buyerId, (value) => value + 1, ifAbsent: () => 1);
    }
    final entries = counts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  List<MapEntry<String, int>> get cancelledOrdersBySeller {
    final counts = <String, int>{};
    for (final order in orders) {
      if (order.status.toLowerCase() != 'cancelled') {
        continue;
      }
      for (final sellerId in order.sellerIds) {
        counts.update(sellerId, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final entries = counts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  List<MapEntry<String, int>> get reportsByProduct {
    final counts = <String, int>{};
    for (final report in productReports) {
      counts.update(report.productId, (value) => value + 1, ifAbsent: () => 1);
    }
    final entries = counts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  User? userById(String userId) {
    for (final user in users) {
      if (user.id == userId) {
        return user;
      }
    }
    return null;
  }

  Product? productById(String productId) {
    for (final product in products) {
      if (product.id == productId) {
        return product;
      }
    }
    return null;
  }

  Order? orderById(String orderId) {
    for (final order in orders) {
      if (order.id == orderId) {
        return order;
      }
    }
    return null;
  }

  AdminUsersState copyWith({
    bool? isLoading,
    List<User>? users,
    List<Product>? products,
    List<Order>? orders,
    List<AdminSupportTicket>? supportTickets,
    List<AdminProductReport>? productReports,
    List<AdminRefundRequest>? refundRequests,
    String? query,
    AdminUserFilter? filter,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? actionMessage,
    bool clearActionMessage = false,
    String? actionUserId,
    bool clearActionUserId = false,
  }) {
    return AdminUsersState(
      isLoading: isLoading ?? this.isLoading,
      users: users ?? this.users,
      products: products ?? this.products,
      orders: orders ?? this.orders,
      supportTickets: supportTickets ?? this.supportTickets,
      productReports: productReports ?? this.productReports,
      refundRequests: refundRequests ?? this.refundRequests,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      actionMessage: clearActionMessage
          ? null
          : (actionMessage ?? this.actionMessage),
      actionUserId: clearActionUserId
          ? null
          : (actionUserId ?? this.actionUserId),
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    users,
    products,
    orders,
    supportTickets,
    productReports,
    refundRequests,
    query,
    filter,
    errorMessage,
    actionMessage,
    actionUserId,
  ];
}
