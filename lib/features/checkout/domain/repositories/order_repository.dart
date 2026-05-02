import 'package:untitled1/features/checkout/domain/entities/order.dart';

abstract class OrderRepository {
  Future<void> placeOrder(Order order);
  Stream<List<Order>> getBuyerOrders(String buyerId);
  Stream<List<Order>> getVendorOrders(String vendorId);
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
