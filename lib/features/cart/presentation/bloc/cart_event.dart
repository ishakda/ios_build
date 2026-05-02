import 'package:equatable/equatable.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';

abstract class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object> get props => [];
}

class LoadCart extends CartEvent {
  const LoadCart();
}

class AddToCart extends CartEvent {
  final Product product;
  const AddToCart(this.product);

  @override
  List<Object> get props => [product];
}

class RemoveFromCart extends CartEvent {
  final String productId;
  const RemoveFromCart(this.productId);

  @override
  List<Object> get props => [productId];
}

class UpdateQuantity extends CartEvent {
  final String productId;
  final int delta;
  const UpdateQuantity(this.productId, this.delta);

  @override
  List<Object> get props => [productId, delta];
}

class ClearCart extends CartEvent {
  const ClearCart();
}
