import 'package:equatable/equatable.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';

class RecentlyViewedState extends Equatable {
  final List<Product> items;

  const RecentlyViewedState({this.items = const []});

  @override
  List<Object> get props => [items];
}
