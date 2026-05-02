import 'dart:convert';

import 'package:hive/hive.dart';

part 'product.g.dart';

@HiveType(typeId: 0)
class Product {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String description;
  @HiveField(3)
  final double price;
  @HiveField(4)
  final double? discountPrice;
  @HiveField(5)
  final String imageUrl;
  @HiveField(6)
  final List<String> images;
  @HiveField(7)
  final double rating;
  @HiveField(8)
  final int reviewsCount;
  @HiveField(9)
  final String category;
  @HiveField(10)
  final bool isFlashDeal;
  @HiveField(11)
  final int stock;
  @HiveField(12)
  final String? sellerId;
  @HiveField(13)
  final List<String> availableColors;
  @HiveField(14)
  final List<String> availableSizes;
  @HiveField(15)
  final List<String> detailImageUrls;
  @HiveField(16)
  final String? brand;
  @HiveField(17)
  final String? parentCategory;
  @HiveField(18)
  final String? subCategory;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.discountPrice,
    required this.imageUrl,
    required this.images,
    required this.rating,
    required this.reviewsCount,
    required this.category,
    this.isFlashDeal = false,
    this.stock = 0,
    this.sellerId,
    this.availableColors = const [],
    this.availableSizes = const [],
    this.detailImageUrls = const [],
    this.brand,
    this.parentCategory,
    this.subCategory,
  });

  double get discountPercentage {
    if (discountPrice == null || price <= 0) return 0;
    return ((price - discountPrice!) / price) * 100;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'discountPrice': discountPrice,
      'imageUrl': imageUrl,
      'images': images,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'category': category,
      'isFlashDeal': isFlashDeal,
      'stock': stock,
      'sellerId': sellerId,
      'availableColors': availableColors,
      'availableSizes': availableSizes,
      'detailImageUrls': detailImageUrls,
      'brand': brand,
      'parentCategory': parentCategory,
      'subCategory': subCategory,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: _asString(json['id']),
      name: _normalizeText(_asString(json['name'])),
      description: _normalizeText(_asString(json['description'])),
      price: _asDouble(json['price']),
      discountPrice: _asNullableDouble(json['discountPrice']),
      imageUrl: _asString(json['imageUrl']),
      images: _asStringList(json['images']),
      rating: _asDouble(json['rating']),
      reviewsCount: _asInt(json['reviewsCount']),
      category: _normalizeText(_asString(json['category'])),
      isFlashDeal: _asBool(json['isFlashDeal']),
      stock: _asInt(json['stock']),
      sellerId: _asNullableString(json['sellerId']),
      availableColors: _asStringList(json['availableColors']),
      availableSizes: _asStringList(json['availableSizes']),
      detailImageUrls: _asStringList(json['detailImageUrls']),
      brand: _asNullableString(json['brand']),
      parentCategory:
          _asNullableString(json['parentCategory']) ??
          _asNullableString(json['category']),
      subCategory:
          _asNullableString(json['subCategory']) ??
          _asNullableString(json['category']),
    );
  }
}

String _asString(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  return value.toString();
}

String? _asNullableString(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }
  return _normalizeText(text);
}

double _asDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

double? _asNullableDouble(Object? value) {
  if (value == null) return null;
  return _asDouble(value);
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  final normalized = value?.toString().toLowerCase();
  if (normalized == 'true') return true;
  if (normalized == 'false') return false;
  return fallback;
}

List<String> _asStringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => _normalizeText(_asString(item)))
        .where((item) => item.isNotEmpty)
        .toList();
  }

  if (value is String && value.trim().isNotEmpty) {
    final trimmed = value.trim();
    if ((trimmed.startsWith('[') && trimmed.endsWith(']')) ||
        (trimmed.startsWith('{') && trimmed.endsWith('}'))) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .map((item) => _normalizeText(_asString(item)))
              .where((item) => item.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    return [_normalizeText(trimmed)];
  }

  return const [];
}

String _normalizeText(String value) {
  if (value.isEmpty) return value;
  var current = value;
  for (var i = 0; i < 10; i++) {
    if (!_looksMojibake(current)) {
      break;
    }
    final repaired = _repairMojibakeOnce(current);
    if (repaired == current) {
      break;
    }
    current = repaired;
  }
  return current;
}

bool _looksMojibake(String value) {
  return value.contains('Ø') ||
      value.contains('Ù') ||
      value.contains('Ã') ||
      value.contains('Â') ||
      value.contains('â') ||
      value.contains('ð') ||
      value.contains('ï¿½') ||
      value.contains('\u0081') ||
      value.contains('\u008d') ||
      value.contains('\u008f') ||
      value.contains('\u0090') ||
      value.contains('\u009d');
}

String _repairMojibakeOnce(String value) {
  try {
    return utf8.decode(latin1.encode(value), allowMalformed: true);
  } catch (_) {
    return value;
  }
}
