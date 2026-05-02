import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:untitled1/core/utils/text_normalizer.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';

part 'cart_item.g.dart';

@HiveType(typeId: 2)
class CartItem extends Equatable {
  @HiveField(0)
  final Product product;
  @HiveField(1)
  final int quantity;

  const CartItem({required this.product, required this.quantity});

  CartItem copyWith({Product? product, int? quantity}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {'product': product.toJson(), 'quantity': quantity};
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(
        normalizeDynamicMap(Map<String, dynamic>.from(json['product'] as Map)),
      ),
      quantity: json['quantity'],
    );
  }

  @override
  List<Object?> get props => [product, quantity];
}
