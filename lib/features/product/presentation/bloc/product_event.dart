import 'package:equatable/equatable.dart';

abstract class ProductEvent extends Equatable {
  const ProductEvent();

  @override
  List<Object?> get props => [];
}

class FetchProducts extends ProductEvent {
  const FetchProducts();
}

class FetchProductsByCategory extends ProductEvent {
  final String category;
  const FetchProductsByCategory(this.category);

  @override
  List<Object?> get props => [category];
}

class SearchProducts extends ProductEvent {
  final String query;
  const SearchProducts(this.query);

  @override
  List<Object?> get props => [query];
}

class FilterProducts extends ProductEvent {
  final double? minPrice;
  final double? maxPrice;
  final double? minRating;
  final String? category;

  const FilterProducts({
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.category,
  });

  @override
  List<Object?> get props => [minPrice, maxPrice, minRating, category];
}
