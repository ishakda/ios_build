import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/core/utils/text_normalizer.dart';
import 'package:untitled1/features/checkout/domain/entities/order.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';
import 'package:untitled1/features/vendor/domain/entities/vendor_store_view.dart';
import 'package:untitled1/features/vendor/domain/repositories/vendor_repository.dart';
import 'package:untitled1/features/vendor/presentation/cubit/vendor_store_state.dart';

class VendorStoreCubit extends Cubit<VendorStoreState> {
  VendorStoreCubit({required this.vendorRepository})
    : super(const VendorStoreState());

  final VendorRepository vendorRepository;
  StreamSubscription<Map<String, dynamic>?>? _profileSubscription;
  StreamSubscription<List<Product>>? _productsSubscription;
  StreamSubscription<List<Order>>? _ordersSubscription;
  StreamSubscription<bool>? _followingSubscription;

  String? _vendorId;
  String? _currentUserId;
  String? _fallbackStoreName;
  Map<String, dynamic>? _profileData;
  Map<String, dynamic> _dashboardMetrics = const {};
  List<Product> _products = const [];
  List<Order> _orders = const [];
  bool _isFollowing = false;

  Future<void> loadStore({
    required String vendorId,
    required String fallbackStoreName,
    required bool includeInsights,
    String? currentUserId,
  }) async {
    _vendorId = vendorId;
    _currentUserId = currentUserId ?? _currentUserId;
    _fallbackStoreName = fallbackStoreName;
    _isFollowing = false;
    _profileData = null;
    _dashboardMetrics = const {};
    _products = const [];
    _orders = const [];
    emit(
      state.copyWith(
        isLoading: true,
        clearErrorMessage: true,
        clearActionErrorMessage: true,
      ),
    );

    await _profileSubscription?.cancel();
    await _productsSubscription?.cancel();
    await _ordersSubscription?.cancel();
    await _followingSubscription?.cancel();

    _profileSubscription = vendorRepository
        .watchStoreProfile(vendorId)
        .listen(
          (profile) {
            _profileData = profile;
            _emitView();
          },
          onError: (_) {
            emit(
              state.copyWith(
                isLoading: false,
                errorMessage:
                    'We could not load this store right now. Please try again later.',
              ),
            );
          },
        );

    _productsSubscription = vendorRepository
        .watchStoreProducts(vendorId)
        .listen(
          (products) {
            _products = products;
            _emitView();
          },
          onError: (_) {
            emit(
              state.copyWith(
                isLoading: false,
                errorMessage:
                    'We could not load this store\'s products right now.',
              ),
            );
          },
        );

    if (currentUserId != null && currentUserId != vendorId) {
      _followingSubscription = vendorRepository
          .isFollowingStore(userId: currentUserId, vendorId: vendorId)
          .listen((isFollowing) {
            _isFollowing = isFollowing;
            _emitView();
          });
    }

    if (includeInsights) {
      _ordersSubscription = vendorRepository
          .watchVendorOrders(vendorId)
          .listen(
            (orders) {
              _orders = orders;
              _emitView();
            },
            onError: (_) {
              emit(
                state.copyWith(
                  isLoading: false,
                  errorMessage:
                      'We could not load your seller analytics right now.',
                ),
              );
            },
          );

      try {
        _dashboardMetrics = await vendorRepository.getSellerDashboardMetrics(
          vendorId: vendorId,
        );
        _emitView();
      } catch (_) {
        // Keep dashboard non-blocking if metrics fetch fails.
      }
    }
  }

  Future<void> toggleFollow() async {
    final vendorId = _vendorId;
    final userId = _currentUserId;
    if (vendorId == null || userId == null || vendorId == userId) return;

    try {
      if (_isFollowing) {
        await vendorRepository.unfollowStore(
          userId: userId,
          vendorId: vendorId,
        );
      } else {
        await vendorRepository.followStore(userId: userId, vendorId: vendorId);
      }
    } catch (_) {
      emit(
        state.copyWith(actionErrorMessage: 'Unable to update follow status.'),
      );
    }
  }

  Future<void> updateStoreInfo({
    required String storeName,
    required String storeDescription,
  }) async {
    final vendorId = _vendorId;
    if (vendorId == null) {
      return;
    }

    emit(state.copyWith(isSaving: true, clearActionErrorMessage: true));
    try {
      await vendorRepository.updateStoreInfo(
        vendorId: vendorId,
        storeName: storeName,
        storeDescription: storeDescription,
      );
      emit(state.copyWith(isSaving: false, clearActionErrorMessage: true));
    } catch (_) {
      emit(
        state.copyWith(
          isSaving: false,
          actionErrorMessage: 'Unable to update store details right now.',
        ),
      );
    }
  }

  Future<void> uploadStoreImage({
    required File imageFile,
    required bool isBanner,
  }) async {
    final vendorId = _vendorId;
    if (vendorId == null) {
      return;
    }

    emit(state.copyWith(isSaving: true, clearActionErrorMessage: true));
    try {
      await vendorRepository.uploadStoreImage(
        vendorId: vendorId,
        imageFile: imageFile,
        isBanner: isBanner,
      );
      emit(state.copyWith(isSaving: false, clearActionErrorMessage: true));
    } catch (_) {
      emit(
        state.copyWith(
          isSaving: false,
          actionErrorMessage: 'Unable to upload this image right now.',
        ),
      );
    }
  }

  void _emitView() {
    final vendorId = _vendorId;
    if (vendorId == null) {
      return;
    }

    double totalEarnings = 0;
    int pendingOrders = 0;
    int completedOrders = 0;
    for (final order in _orders) {
      final normalizedStatus = order.status.toLowerCase();
      final sellerItems = order.items
          .where((item) => item.product.sellerId == vendorId)
          .toList();
      if (sellerItems.isEmpty) {
        continue;
      }
      final sellerTotal = sellerItems.fold<double>(
        0,
        (total, item) => total + (item.product.price * item.quantity),
      );
      if (normalizedStatus == 'delivered' || normalizedStatus == 'received') {
        totalEarnings += sellerTotal;
        completedOrders++;
      } else if (normalizedStatus != 'cancelled') {
        pendingOrders++;
      }
    }

    emit(
      state.copyWith(
        isLoading: false,
        clearErrorMessage: true,
        view: VendorStoreView(
          vendorId: vendorId,
          storeName: normalizeText(
            _profileData?['storeName']?.toString() ??
                _fallbackStoreName ??
                'Store',
          ),
          storeDescription: normalizeText(
            _profileData?['storeDescription']?.toString() ??
                'Premium products for modern lifestyle.',
          ),
          coverImageUrl: _profileData?['coverImageUrl'],
          storeLogoUrl: _profileData?['storeLogo'],
          products: _products,
          totalEarnings: totalEarnings,
          pendingOrders: pendingOrders,
          completedOrders: completedOrders,
          followerCount: _profileData?['followerCount'] ?? 0,
          isFollowing: _isFollowing,
          weeklyViews: (_dashboardMetrics['views_count'] as num?)?.toInt() ?? 0,
          weeklyClicks:
              (_dashboardMetrics['clicks_count'] as num?)?.toInt() ?? 0,
          weeklySalesCount:
              (_dashboardMetrics['sales_this_week'] as num?)?.toInt() ?? 0,
          topProductName: normalizeNullableText(
            _dashboardMetrics['top_product_name']?.toString(),
          ),
          isSellerApproved: _profileData?['isSellerApproved'] == true,
          ctr: (_dashboardMetrics['ctr'] as num?)?.toDouble() ?? 0,
          clickToCartRate:
              (_dashboardMetrics['click_to_cart_rate'] as num?)?.toDouble() ??
              0,
          cartToPurchaseRate:
              (_dashboardMetrics['cart_to_purchase_rate'] as num?)
                  ?.toDouble() ??
              0,
          overallPurchaseRate:
              (_dashboardMetrics['overall_purchase_rate'] as num?)
                  ?.toDouble() ??
              0,
          lowStockCount:
              (_dashboardMetrics['low_stock_count'] as num?)?.toInt() ?? 0,
          isVerifiedSeller: _profileData?['isVerifiedSeller'] == true,
          verificationLevel:
              _profileData?['verificationLevel']?.toString() ?? 'none',
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _profileSubscription?.cancel();
    await _productsSubscription?.cancel();
    await _ordersSubscription?.cancel();
    await _followingSubscription?.cancel();
    return super.close();
  }
}
