import 'package:dartz/dartz.dart';
import 'package:untitled1/core/error/failures.dart';
import 'package:untitled1/features/product/data/datasources/product_local_data_source.dart';
import 'package:untitled1/features/product/data/datasources/product_remote_data_source.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';
import 'package:untitled1/features/product/domain/entities/review.dart';
import 'package:untitled1/features/product/domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  static List<Product>? _memoryCache;
  static DateTime? _memoryCacheAt;
  static const Duration _memoryTtl = Duration(seconds: 45);

  final ProductRemoteDataSource remoteDataSource;
  final ProductLocalDataSource localDataSource;

  ProductRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, List<Product>>> getProducts() async {
    final now = DateTime.now();
    if (_memoryCache != null &&
        _memoryCacheAt != null &&
        now.difference(_memoryCacheAt!) < _memoryTtl) {
      return Right(List<Product>.from(_memoryCache!));
    }

    try {
      final remoteProducts = await remoteDataSource.getProducts();
      _memoryCache = remoteProducts;
      _memoryCacheAt = now;
      await localDataSource.cacheProducts(remoteProducts);
      return Right(remoteProducts);
    } catch (e) {
      try {
        final localProducts = await localDataSource.getLastProducts();
        if (localProducts.isNotEmpty) {
          _memoryCache = localProducts;
          _memoryCacheAt = now;
          return Right(localProducts);
        }
        return Left(ServerFailure(e.toString()));
      } catch (cacheError) {
        return Left(ServerFailure(e.toString()));
      }
    }
  }

  @override
  Future<Either<Failure, List<Product>>> getProductsByCategory(
    String category,
  ) async {
    try {
      final remoteProducts = await remoteDataSource.getProductsByCategory(
        category,
      );
      return Right(remoteProducts);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<List<Product>> getProductsStream() {
    return remoteDataSource.getProductsStream();
  }

  @override
  Future<Either<Failure, Product>> getProductDetails(String id) async {
    try {
      final product = await remoteDataSource.getProductDetails(id);
      return Right(product);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Product>>> searchProducts(String query) async {
    try {
      final results = await remoteDataSource.searchProducts(query);
      return Right(results);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<void> addProduct(Product product) async {
    await remoteDataSource.addProduct(product);
  }

  @override
  Future<void> updateProduct(Product product) async {
    await remoteDataSource.updateProduct(product);
  }

  @override
  Future<void> deleteProduct(String productId) async {
    await remoteDataSource.deleteProduct(productId);
  }

  @override
  Future<void> updateStock(String productId, int quantityChange) async {
    await remoteDataSource.updateStock(productId, quantityChange);
  }

  @override
  Future<void> trackProductEvent({
    required String productId,
    required String eventType,
    String? viewerId,
  }) async {
    await remoteDataSource.trackProductEvent(
      productId: productId,
      eventType: eventType,
      viewerId: viewerId,
    );
  }

  @override
  Future<Either<Failure, List<Review>>> getProductReviews(
    String productId,
  ) async {
    try {
      final reviews = await remoteDataSource.getProductReviews(productId);
      return Right(reviews);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addReview(Review review) async {
    try {
      await remoteDataSource.addReview(review);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> hasUserPurchasedProduct(
    String userId,
    String productId,
  ) async {
    try {
      final hasPurchased = await remoteDataSource.hasUserPurchasedProduct(
        userId,
        productId,
      );
      return Right(hasPurchased);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> reportProduct({
    required String productId,
    required String reason,
    String? details,
  }) async {
    try {
      await remoteDataSource.reportProduct(
        productId: productId,
        reason: reason,
        details: details,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
