import 'package:equatable/equatable.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';

abstract class RecentlyViewedEvent extends Equatable {
  const RecentlyViewedEvent();

  @override
  List<Object> get props => [];
}

class LoadRecentlyViewed extends RecentlyViewedEvent {
  const LoadRecentlyViewed();
}

class AddToRecentlyViewed extends RecentlyViewedEvent {
  final Product product;
  const AddToRecentlyViewed(this.product);

  @override
  List<Object> get props => [product];
}
