import 'package:flutter_test/flutter_test.dart';
import 'package:untitled1/features/product/data/datasources/product_local_data_source.dart';
import 'package:untitled1/features/product/data/datasources/product_remote_data_source.dart';
import 'package:untitled1/features/product/data/repositories/product_repository_impl.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';
import 'package:untitled1/features/product/domain/entities/review.dart';

class FakeProductRemoteDataSource implements ProductRemoteDataSource {
  FakeProductRemoteDataSource({
    this.products = const [],
    this.shouldThrow = false,
  });

  final List<Product> products;
  final bool shouldThrow;

  @override
  Future<List<Product>> getProducts() async {
    if (shouldThrow) {
      throw Exception('remote failed');
    }
    return products;
  }

  @override
  Stream<List<Product>> getProductsStream() => Stream.value(products);

  @override
  Future<List<Product>> getProductsByCategory(String category) {
    throw UnimplementedError();
  }

  @override
  Future<List<Product>> searchProducts(String query) {
    throw UnimplementedError();
  }

  @override
  Future<Product> getProductDetails(String id) {
    throw UnimplementedError();
  }

  @override
  Future<void> addProduct(Product product) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateProduct(Product product) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteProduct(String productId) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateStock(String productId, int quantityChange) {
    throw UnimplementedError();
  }

  @override
  Future<void> trackProductEvent({
    required String productId,
    required String eventType,
    String? viewerId,
  }) async {}

  @override
  Future<List<Review>> getProductReviews(String productId) {
    throw UnimplementedError();
  }

  @override
  Future<void> addReview(Review review) {
    throw UnimplementedError();
  }

  @override
  Future<bool> hasUserPurchasedProduct(String userId, String productId) {
    throw UnimplementedError();
  }

  @override
  Future<void> reportProduct({
    required String productId,
    required String reason,
    String? details,
  }) {
    throw UnimplementedError();
  }
}

class FakeProductLocalDataSource implements ProductLocalDataSource {
  FakeProductLocalDataSource({this.cachedProducts = const []});

  final List<Product> cachedProducts;
  List<Product>? lastCachedProducts;

  @override
  Future<List<Product>> getLastProducts() async => cachedProducts;

  @override
  Future<void> cacheProducts(List<Product> productsToCache) async {
    lastCachedProducts = productsToCache;
  }

  @override
  Future<void> clearCache() async {
    lastCachedProducts = const [];
  }
}

void main() {
  group('ProductRepositoryImpl', () {
    final sampleProduct = Product(
      id: 'p1',
      name: 'Phone',
      description: 'Test product',
      price: 1000,
      imageUrl: 'https://example.com/image.png',
      images: const ['https://example.com/image.png'],
      rating: 4.5,
      reviewsCount: 10,
      category: 'Phones',
    );

    test('returns remote products and caches them on success', () async {
      final remote = FakeProductRemoteDataSource(products: [sampleProduct]);
      final local = FakeProductLocalDataSource();
      final repository = ProductRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: local,
      );

      final result = await repository.getProducts();

      result.fold(
        (failure) =>
            fail('expected products but got failure: ${failure.message}'),
        (products) {
          expect(products, hasLength(1));
          expect(products.first.id, sampleProduct.id);
        },
      );
      expect(local.lastCachedProducts, isNotNull);
      expect(local.lastCachedProducts!.first.id, sampleProduct.id);
    });

    test('returns cached products when remote fetch fails', () async {
      final remote = FakeProductRemoteDataSource(shouldThrow: true);
      final local = FakeProductLocalDataSource(cachedProducts: [sampleProduct]);
      final repository = ProductRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: local,
      );

      final result = await repository.getProducts();

      result.fold(
        (failure) => fail(
          'expected cached products but got failure: ${failure.message}',
        ),
        (products) {
          expect(products, hasLength(1));
          expect(products.first.id, sampleProduct.id);
        },
      );
    });
  });
}
