import 'package:dartz/dartz.dart';
import 'package:untitled1/core/error/failures.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';
import 'package:untitled1/features/product/domain/entities/review.dart';

abstract class ProductRepository {
  Future<Either<Failure, List<Product>>> getProducts();
  Stream<List<Product>> getProductsStream();
  Future<Either<Failure, List<Product>>> getProductsByCategory(String category);
  Future<Either<Failure, Product>> getProductDetails(String id);
  Future<Either<Failure, List<Product>>> searchProducts(String query);
  Future<void> addProduct(Product product);
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(String productId);
  Future<void> updateStock(String productId, int quantityChange);
  Future<void> trackProductEvent({
    required String productId,
    required String eventType,
    String? viewerId,
  });

  // Reviews
  Future<Either<Failure, List<Review>>> getProductReviews(String productId);
  Future<Either<Failure, void>> addReview(Review review);
  Future<Either<Failure, bool>> hasUserPurchasedProduct(
    String userId,
    String productId,
  );
  Future<Either<Failure, void>> reportProduct({
    required String productId,
    required String reason,
    String? details,
  });
}
