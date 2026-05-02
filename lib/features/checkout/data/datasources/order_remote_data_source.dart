import 'package:untitled1/core/constants/supabase_constants.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/features/checkout/domain/entities/order.dart'
    as domain;

abstract class OrderRemoteDataSource {
  Future<void> placeOrder(domain.Order order);
  Stream<List<domain.Order>> getBuyerOrders(String buyerId);
  Stream<List<domain.Order>> getVendorOrders(String vendorId);
  Future<void> updateOrderStatus({
    required String orderId,
    required String newStatus,
  });
  Future<void> submitRefundRequest({
    required String orderId,
    required String reason,
    String? details,
  });
}

class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  final String collectionPath = SupabaseTables.orders;

  @override
  Stream<List<domain.Order>> getVendorOrders(String vendorId) {
    return SupabaseService.client
        .from(collectionPath)
        .stream(primaryKey: ['id'])
        .map((rows) {
          final orders = rows
              .where((row) {
                final sellerIds = List<String>.from(
                  row['sellerIds'] ?? const [],
                );
                return sellerIds.contains(vendorId);
              })
              .map(domain.Order.fromJson)
              .toList();
          orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
          return orders;
        });
  }

  @override
  Future<void> placeOrder(domain.Order order) async {
    await SupabaseService.client.rpc(
      'place_order',
      params: {'p_order': order.toJson()},
    );
  }

  @override
  Future<void> updateOrderStatus({
    required String orderId,
    required String newStatus,
  }) async {
    await SupabaseService.client.rpc(
      'set_order_status',
      params: {'p_order_id': orderId, 'p_new_status': newStatus},
    );
  }

  @override
  Stream<List<domain.Order>> getBuyerOrders(String buyerId) {
    return SupabaseService.client
        .from(collectionPath)
        .stream(primaryKey: ['id'])
        .eq('buyerId', buyerId)
        .map((rows) {
          final orders = rows.map(domain.Order.fromJson).toList();
          orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
          return orders;
        });
  }

  @override
  Future<void> submitRefundRequest({
    required String orderId,
    required String reason,
    String? details,
  }) async {
    await SupabaseService.client.rpc(
      'submit_refund_request',
      params: {'p_order_id': orderId, 'p_reason': reason, 'p_details': details},
    );
  }
}
