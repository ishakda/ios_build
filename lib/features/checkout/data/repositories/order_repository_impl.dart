import 'package:untitled1/features/checkout/data/datasources/order_remote_data_source.dart';
import 'package:untitled1/features/checkout/domain/entities/order.dart'
    as domain;
import 'package:untitled1/features/checkout/domain/repositories/order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  final OrderRemoteDataSource remoteDataSource;

  OrderRepositoryImpl({required this.remoteDataSource});

  @override
  Future<void> placeOrder(domain.Order order) async {
    return await remoteDataSource.placeOrder(order);
  }

  @override
  Stream<List<domain.Order>> getBuyerOrders(String buyerId) {
    return remoteDataSource.getBuyerOrders(buyerId);
  }

  @override
  Stream<List<domain.Order>> getVendorOrders(String vendorId) {
    return remoteDataSource.getVendorOrders(vendorId);
  }

  @override
  Future<void> updateOrderStatus({
    required String orderId,
    required String newStatus,
  }) async {
    await remoteDataSource.updateOrderStatus(
      orderId: orderId,
      newStatus: newStatus,
    );
  }

  @override
  Future<void> submitRefundRequest({
    required String orderId,
    required String reason,
    String? details,
  }) async {
    await remoteDataSource.submitRefundRequest(
      orderId: orderId,
      reason: reason,
      details: details,
    );
  }
}
