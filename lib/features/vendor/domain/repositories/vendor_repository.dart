import 'dart:io';

import 'package:untitled1/features/checkout/domain/entities/order.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';

abstract class VendorRepository {
  Stream<Map<String, dynamic>?> watchStoreProfile(String vendorId);
  Stream<List<Product>> watchStoreProducts(String vendorId);
  Stream<List<Order>> watchVendorOrders(String vendorId);
  Future<void> updateStoreInfo({
    required String vendorId,
    required String storeName,
    required String storeDescription,
  });
  Future<void> uploadStoreImage({
    required String vendorId,
    required File imageFile,
    required bool isBanner,
  });
  Future<void> updateOrderStatus({
    required String orderId,
    required String buyerId,
    required String newStatus,
  });
  Future<void> followStore({required String userId, required String vendorId});
  Future<void> unfollowStore({
    required String userId,
    required String vendorId,
  });
  Stream<bool> isFollowingStore({
    required String userId,
    required String vendorId,
  });
  Stream<int> watchFollowerCount(String vendorId);
  Future<Map<String, dynamic>> getSellerDashboardMetrics({
    required String vendorId,
  });
}
