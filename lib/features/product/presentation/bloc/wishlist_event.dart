import 'package:equatable/equatable.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';

abstract class WishlistEvent extends Equatable {
  const WishlistEvent();

  @override
  List<Object> get props => [];
}

class LoadWishlist extends WishlistEvent {
  const LoadWishlist();
}

class ToggleWishlist extends WishlistEvent {
  final Product product;
  const ToggleWishlist(this.product);

  @override
  List<Object> get props => [product];
}
