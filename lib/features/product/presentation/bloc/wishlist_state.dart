import 'package:equatable/equatable.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';

class WishlistState extends Equatable {
  final List<Product> items;

  const WishlistState({this.items = const []});

  @override
  List<Object> get props => [items];
}
