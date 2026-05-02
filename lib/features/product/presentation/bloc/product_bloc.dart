import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/features/product/domain/repositories/product_repository.dart';
import 'package:untitled1/features/product/presentation/bloc/product_event.dart';
import 'package:untitled1/features/product/presentation/bloc/product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final ProductRepository productRepository;

  ProductBloc({required this.productRepository}) : super(ProductInitial()) {
    on<FetchProducts>(_onFetchProducts);
    on<FetchProductsByCategory>(_onFetchProductsByCategory);
    on<SearchProducts>(_onSearchProducts);
    on<FilterProducts>(_onFilterProducts);
  }

  Future<void> _onFilterProducts(
    FilterProducts event,
    Emitter<ProductState> emit,
  ) async {
    emit(ProductLoading());
    final result = await productRepository.getProducts();
    result.fold((failure) => emit(ProductError(failure.message)), (products) {
      var filtered = products;
      if (event.category != null && event.category != 'All') {
        filtered = filtered.where((p) => p.category == event.category).toList();
      }
      if (event.minPrice != null) {
        filtered = filtered
            .where((p) => (p.discountPrice ?? p.price) >= event.minPrice!)
            .toList();
      }
      if (event.maxPrice != null) {
        filtered = filtered
            .where((p) => (p.discountPrice ?? p.price) <= event.maxPrice!)
            .toList();
      }
      if (event.minRating != null) {
        filtered = filtered.where((p) => p.rating >= event.minRating!).toList();
      }
      emit(ProductLoaded(filtered));
    });
  }

  Future<void> _onFetchProducts(
    FetchProducts event,
    Emitter<ProductState> emit,
  ) async {
    emit(ProductLoading());
    final result = await productRepository.getProducts();
    result.fold(
      (failure) => emit(ProductError(failure.message)),
      (products) => emit(ProductLoaded(products)),
    );
  }

  Future<void> _onFetchProductsByCategory(
    FetchProductsByCategory event,
    Emitter<ProductState> emit,
  ) async {
    emit(ProductLoading());
    final result = await productRepository.getProductsByCategory(
      event.category,
    );
    result.fold(
      (failure) => emit(ProductError(failure.message)),
      (products) => emit(ProductLoaded(products)),
    );
  }

  Future<void> _onSearchProducts(
    SearchProducts event,
    Emitter<ProductState> emit,
  ) async {
    emit(ProductLoading());
    final result = await productRepository.searchProducts(event.query);
    result.fold(
      (failure) => emit(ProductError(failure.message)),
      (products) => emit(ProductLoaded(products)),
    );
  }
}
