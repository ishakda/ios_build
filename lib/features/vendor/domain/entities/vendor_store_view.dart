import 'package:equatable/equatable.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';

class VendorStoreView extends Equatable {
  const VendorStoreView({
    required this.vendorId,
    required this.storeName,
    required this.storeDescription,
    this.coverImageUrl,
    this.storeLogoUrl,
    this.products = const [],
    this.totalEarnings = 0,
    this.pendingOrders = 0,
    this.completedOrders = 0,
    this.followerCount = 0,
    this.isFollowing = false,
    this.weeklyViews = 0,
    this.weeklyClicks = 0,
    this.weeklySalesCount = 0,
    this.topProductName,
    this.isSellerApproved = false,
    this.isVerifiedSeller = false,
    this.verificationLevel = 'none',
    this.ctr = 0,
    this.clickToCartRate = 0,
    this.cartToPurchaseRate = 0,
    this.overallPurchaseRate = 0,
    this.lowStockCount = 0,
  });

  final String vendorId;
  final String storeName;
  final String storeDescription;
  final String? coverImageUrl;
  final String? storeLogoUrl;
  final List<Product> products;
  final double totalEarnings;
  final int pendingOrders;
  final int completedOrders;
  final int followerCount;
  final bool isFollowing;
  final int weeklyViews;
  final int weeklyClicks;
  final int weeklySalesCount;
  final String? topProductName;
  final bool isSellerApproved;
  final bool isVerifiedSeller;
  final String verificationLevel;
  final double ctr;
  final double clickToCartRate;
  final double cartToPurchaseRate;
  final double overallPurchaseRate;
  final int lowStockCount;

  VendorStoreView copyWith({
    String? vendorId,
    String? storeName,
    String? storeDescription,
    String? coverImageUrl,
    String? storeLogoUrl,
    List<Product>? products,
    double? totalEarnings,
    int? pendingOrders,
    int? completedOrders,
    int? followerCount,
    bool? isFollowing,
    int? weeklyViews,
    int? weeklyClicks,
    int? weeklySalesCount,
    String? topProductName,
    bool? isSellerApproved,
    bool? isVerifiedSeller,
    String? verificationLevel,
    double? ctr,
    double? clickToCartRate,
    double? cartToPurchaseRate,
    double? overallPurchaseRate,
    int? lowStockCount,
  }) {
    return VendorStoreView(
      vendorId: vendorId ?? this.vendorId,
      storeName: storeName ?? this.storeName,
      storeDescription: storeDescription ?? this.storeDescription,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      storeLogoUrl: storeLogoUrl ?? this.storeLogoUrl,
      products: products ?? this.products,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      completedOrders: completedOrders ?? this.completedOrders,
      followerCount: followerCount ?? this.followerCount,
      isFollowing: isFollowing ?? this.isFollowing,
      weeklyViews: weeklyViews ?? this.weeklyViews,
      weeklyClicks: weeklyClicks ?? this.weeklyClicks,
      weeklySalesCount: weeklySalesCount ?? this.weeklySalesCount,
      topProductName: topProductName ?? this.topProductName,
      isSellerApproved: isSellerApproved ?? this.isSellerApproved,
      isVerifiedSeller: isVerifiedSeller ?? this.isVerifiedSeller,
      verificationLevel: verificationLevel ?? this.verificationLevel,
      ctr: ctr ?? this.ctr,
      clickToCartRate: clickToCartRate ?? this.clickToCartRate,
      cartToPurchaseRate: cartToPurchaseRate ?? this.cartToPurchaseRate,
      overallPurchaseRate: overallPurchaseRate ?? this.overallPurchaseRate,
      lowStockCount: lowStockCount ?? this.lowStockCount,
    );
  }

  @override
  List<Object?> get props => [
    vendorId,
    storeName,
    storeDescription,
    coverImageUrl,
    storeLogoUrl,
    products,
    totalEarnings,
    pendingOrders,
    completedOrders,
    followerCount,
    isFollowing,
    weeklyViews,
    weeklyClicks,
    weeklySalesCount,
    topProductName,
    isSellerApproved,
    isVerifiedSeller,
    verificationLevel,
    ctr,
    clickToCartRate,
    cartToPurchaseRate,
    overallPurchaseRate,
    lowStockCount,
  ];
}
