import 'dart:io';

import 'package:untitled1/core/constants/supabase_constants.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/utils/text_normalizer.dart';
import 'package:untitled1/features/checkout/domain/entities/order.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';
import 'package:untitled1/features/vendor/domain/repositories/vendor_repository.dart';

class VendorRepositoryImpl implements VendorRepository {
  Future<void> _updateOwnStoreProfile(Map<String, dynamic> payload) async {
    await SupabaseService.client.rpc(
      'update_own_profile',
      params: {'p_profile': payload},
    );
  }

  @override
  Stream<Map<String, dynamic>?> watchStoreProfile(String vendorId) {
    return SupabaseService.client
        .from(SupabaseTables.userPublicProfiles)
        .stream(primaryKey: ['id'])
        .eq('id', vendorId)
        .map(
          (rows) => rows.isEmpty
              ? null
              : normalizeDynamicMap(Map<String, dynamic>.from(rows.first)),
        );
  }

  @override
  Stream<List<Product>> watchStoreProducts(String vendorId) {
    return SupabaseService.client
        .from(SupabaseTables.products)
        .stream(primaryKey: ['id'])
        .eq('sellerId', vendorId)
        .map((rows) {
          final products = <Product>[];
          for (final row in rows) {
            try {
              products.add(
                Product.fromJson(normalizeDynamicMap(Map<String, dynamic>.from(row))),
              );
            } catch (_) {
              // Skip malformed rows to keep seller view available.
            }
          }
          return products;
        });
  }

  @override
  Stream<List<Order>> watchVendorOrders(String vendorId) {
    return SupabaseService.client
        .from(SupabaseTables.orders)
        .stream(primaryKey: ['id'])
        .asyncMap((rows) async {
          final orders = rows
              .where((row) {
                final sellerIds = List<String>.from(
                  row['sellerIds'] ?? const [],
                );
                return sellerIds.contains(vendorId);
              })
              .map(Order.fromJson)
              .toList();

          final missingBuyerPhoneIds = orders
              .where((order) => order.buyerPhone == null)
              .map((order) => order.buyerId)
              .toSet()
              .toList();

          if (missingBuyerPhoneIds.isNotEmpty) {
            try {
              final response = await SupabaseService.client.rpc(
                'get_vendor_order_contacts',
                params: {'p_vendor_id': vendorId},
              );

              final phoneByBuyerId = <String, String>{};
              final nameByBuyerId = <String, String>{};
              if (response is List) {
                for (final row in response) {
                  if (row is Map) {
                    final buyerId = row['buyer_id']?.toString() ?? '';
                    final phone = row['phone_number']?.toString().trim() ?? '';
                    final name = row['buyer_name']?.toString().trim() ?? '';
                    if (buyerId.isNotEmpty) {
                      if (phone.isNotEmpty) {
                        phoneByBuyerId[buyerId] = phone;
                      }
                      if (name.isNotEmpty) {
                        nameByBuyerId[buyerId] = name;
                      }
                    }
                  }
                }
              }

              for (var i = 0; i < orders.length; i++) {
                final order = orders[i];
                if (order.buyerPhone != null && order.buyerName != null) {
                  continue;
                }
                final fallbackPhone = phoneByBuyerId[order.buyerId];
                final fallbackName = nameByBuyerId[order.buyerId];
                if ((fallbackPhone == null || fallbackPhone.isEmpty) &&
                    (fallbackName == null || fallbackName.isEmpty)) {
                  continue;
                }
                orders[i] = order.copyWith(
                  shippingAddress: {
                    ...order.shippingAddress,
                    if (fallbackPhone != null && fallbackPhone.isNotEmpty)
                      'buyerPhone': fallbackPhone,
                    if (fallbackName != null && fallbackName.isNotEmpty)
                      'buyerName': fallbackName,
                  },
                );
              }
            } catch (_) {
              // Keep orders visible even if buyer contact enrichment fails.
            }
          }

          orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
          return orders;
        });
  }

  @override
  Future<void> updateStoreInfo({
    required String vendorId,
    required String storeName,
    required String storeDescription,
  }) {
    return _updateOwnStoreProfile({
      'storeName': storeName,
      'storeDescription': storeDescription,
    });
  }

  @override
  Future<void> uploadStoreImage({
    required String vendorId,
    required File imageFile,
    required bool isBanner,
  }) async {
    final fileName = isBanner
        ? 'banner_${DateTime.now().millisecondsSinceEpoch}.jpg'
        : 'logo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final url = await SupabaseService.uploadPublicFile(
      bucket: SupabaseBuckets.storeMedia,
      path: 'stores/$vendorId/$fileName',
      file: imageFile,
      contentType: 'image/jpeg',
    );

    await _updateOwnStoreProfile({
      isBanner ? 'coverImageUrl' : 'storeLogo': url,
    });
  }

  @override
  Future<void> updateOrderStatus({
    required String orderId,
    required String buyerId,
    required String newStatus,
  }) async {
    await SupabaseService.client.rpc(
      'vendor_update_order_status',
      params: {
        'p_order_id': orderId,
        'p_buyer_id': buyerId,
        'p_new_status': newStatus,
      },
    );
  }

  @override
  Future<void> followStore({
    required String userId,
    required String vendorId,
  }) async {
    await SupabaseService.client.rpc(
      'follow_store',
      params: {'p_user_id': userId, 'p_vendor_id': vendorId},
    );
  }

  @override
  Future<void> unfollowStore({
    required String userId,
    required String vendorId,
  }) async {
    await SupabaseService.client.rpc(
      'unfollow_store',
      params: {'p_user_id': userId, 'p_vendor_id': vendorId},
    );
  }

  @override
  Stream<bool> isFollowingStore({
    required String userId,
    required String vendorId,
  }) {
    return SupabaseService.client
        .from(SupabaseTables.users)
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) {
          if (rows.isEmpty) {
            return false;
          }
          final following = rows.first['followingStores'] as List<dynamic>?;
          return following?.contains(vendorId) ?? false;
        });
  }

  @override
  Stream<int> watchFollowerCount(String vendorId) {
    return SupabaseService.client
        .from(SupabaseTables.userPublicProfiles)
        .stream(primaryKey: ['id'])
        .eq('id', vendorId)
        .map((rows) {
          if (rows.isEmpty) {
            return 0;
          }
          return rows.first['followerCount'] as int? ?? 0;
        });
  }

  @override
  Future<Map<String, dynamic>> getSellerDashboardMetrics({
    required String vendorId,
  }) async {
    final result = await SupabaseService.client.rpc(
      'get_seller_dashboard',
      params: {'p_vendor_id': vendorId},
    );

    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return const {};
  }
}
