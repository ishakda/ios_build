import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/utils/text_normalizer.dart';
import 'package:untitled1/features/cart/domain/entities/cart_item.dart';

part 'order.g.dart';

@HiveType(typeId: 3)
class Order extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final List<CartItem> items;
  @HiveField(2)
  final double totalAmount;
  @HiveField(3)
  final DateTime orderDate;
  @HiveField(4)
  final String status; // e.g., 'Pending', 'Processing', 'Shipped', 'Delivered'
  @HiveField(5)
  final String buyerId;
  @HiveField(6)
  final List<String> sellerIds;
  @HiveField(7)
  final String orderNumber;
  @HiveField(8)
  final double shippingFee;
  @HiveField(9)
  final String deliveryType;
  @HiveField(10)
  final String paymentMethod;
  @HiveField(11)
  final Map<String, dynamic> shippingAddress;
  @HiveField(12)
  final String paymentStatus;

  const Order({
    required this.id,
    required this.items,
    required this.totalAmount,
    required this.orderDate,
    required this.status,
    required this.buyerId,
    this.sellerIds = const [],
    required this.orderNumber,
    this.shippingFee = 0,
    this.deliveryType = 'home',
    this.paymentMethod = 'cod',
    this.shippingAddress = const {},
    this.paymentStatus = 'pending',
  });

  Order copyWith({
    String? id,
    List<CartItem>? items,
    double? totalAmount,
    DateTime? orderDate,
    String? status,
    String? buyerId,
    List<String>? sellerIds,
    String? orderNumber,
    double? shippingFee,
    String? deliveryType,
    String? paymentMethod,
    Map<String, dynamic>? shippingAddress,
    String? paymentStatus,
  }) {
    return Order(
      id: id ?? this.id,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      orderDate: orderDate ?? this.orderDate,
      status: status ?? this.status,
      buyerId: buyerId ?? this.buyerId,
      sellerIds: sellerIds ?? this.sellerIds,
      orderNumber: orderNumber ?? this.orderNumber,
      shippingFee: shippingFee ?? this.shippingFee,
      deliveryType: deliveryType ?? this.deliveryType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      paymentStatus: paymentStatus ?? this.paymentStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'items': items.map((item) => item.toJson()).toList(),
      'totalAmount': totalAmount,
      'orderDate': orderDate.toIso8601String(),
      'status': status,
      'buyerId': buyerId,
      'sellerIds': sellerIds,
      'orderNumber': orderNumber,
      'shippingFee': shippingFee,
      'deliveryType': deliveryType,
      'paymentMethod': paymentMethod,
      'shippingAddress': shippingAddress,
      'paymentStatus': paymentStatus,
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawShippingAddress = json['shippingAddress'];
    return Order(
      id: json['id'] ?? '',
      items: (json['items'] as List).map((i) => CartItem.fromJson(i)).toList(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      orderDate: SupabaseService.parseDateTime(json['orderDate']),
      status: normalizeText(json['status']?.toString() ?? 'Pending'),
      buyerId: json['buyerId'] ?? '',
      sellerIds: List<String>.from(json['sellerIds'] ?? []),
      orderNumber: normalizeText(
        json['orderNumber']?.toString() ??
            (json['id']?.toString().split('-').last ?? ''),
      ),
      shippingFee: (json['shippingFee'] as num?)?.toDouble() ?? 0,
      deliveryType: json['deliveryType']?.toString() ?? 'home',
      paymentMethod: json['paymentMethod']?.toString() ?? 'cod',
      shippingAddress: rawShippingAddress is Map
          ? normalizeDynamicMap(Map<String, dynamic>.from(rawShippingAddress))
          : const {},
      paymentStatus:
          json['paymentStatus']?.toString() ??
          json['payment_status']?.toString() ??
          'pending',
    );
  }

  @override
  List<Object?> get props => [
    id,
    items,
    totalAmount,
    orderDate,
    status,
    buyerId,
    sellerIds,
    orderNumber,
    shippingFee,
    deliveryType,
    paymentMethod,
    shippingAddress,
    paymentStatus,
  ];

  String get displayNumber {
    final normalized = orderNumber.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }

    final rawId = id.trim();
    if (rawId.isEmpty) {
      return 'ORD-UNKNOWN';
    }

    final digits = rawId.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 6) {
      return 'ORD-${digits.substring(digits.length - 6)}';
    }

    final compact = rawId.length > 8 ? rawId.substring(rawId.length - 8) : rawId;
    return 'ORD-${compact.toUpperCase()}';
  }

  String? get buyerPhone {
    const keys = ['phoneNumber', 'phone', 'buyerPhone'];
    for (final key in keys) {
      final value = shippingAddress[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return normalizeText(value);
      }
    }
    return null;
  }

  String? get buyerName {
    const keys = ['buyerName', 'name', 'fullName'];
    for (final key in keys) {
      final value = shippingAddress[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return normalizeText(value);
      }
    }
    return null;
  }

  String get shippingAddressSummary {
    final parts = <String>[];
    for (final key in const ['wilaya', 'commune', 'address']) {
      final value = shippingAddress[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        parts.add(normalizeText(value));
      }
    }
    return parts.join(' - ');
  }
}
