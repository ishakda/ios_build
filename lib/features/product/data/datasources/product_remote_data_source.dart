import 'package:untitled1/core/constants/supabase_constants.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/utils/text_normalizer.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';
import 'package:untitled1/features/product/domain/entities/review.dart';

abstract class ProductRemoteDataSource {
  Future<List<Product>> getProducts();
  Stream<List<Product>> getProductsStream();
  Future<List<Product>> getProductsByCategory(String category);
  Future<List<Product>> searchProducts(String query);
  Future<Product> getProductDetails(String id);
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
  Future<List<Review>> getProductReviews(String productId);
  Future<void> addReview(Review review);
  Future<bool> hasUserPurchasedProduct(String userId, String productId);
  Future<void> reportProduct({
    required String productId,
    required String reason,
    String? details,
  });
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final String collectionPath = SupabaseTables.products;

  ProductRemoteDataSourceImpl();

  dynamic get _products => SupabaseService.client.from(collectionPath);

  List<Product> _parseProducts(dynamic response) {
    if (response is! List) {
      return const [];
    }

    final products = <Product>[];
    for (final item in response) {
      if (item is! Map) {
        continue;
      }

      try {
        products.add(
          Product.fromJson(
            normalizeDynamicMap(Map<String, dynamic>.from(item)),
          ),
        );
      } catch (_) {
        // Skip malformed rows instead of failing the entire product feed.
      }
    }
    return products;
  }

  @override
  Future<List<Product>> getProducts() async {
    final response = await _products.select();
    return _parseProducts(response);
  }

  @override
  Stream<List<Product>> getProductsStream() {
    return _products.stream(primaryKey: ['id']).map((rows) {
      return _parseProducts(rows);
    });
  }

  @override
  Future<List<Product>> getProductsByCategory(String category) async {
    final byCategory = await _products.select().eq('category', category);
    final byParent = await _products.select().eq('parentCategory', category);
    final bySubcategory = await _products.select().eq('subCategory', category);

    final merged = <String, Map<String, dynamic>>{};
    for (final item in [...byCategory, ...byParent, ...bySubcategory]) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final id = map['id']?.toString();
      if (id == null || id.isEmpty) {
        continue;
      }
      merged[id] = map;
    }

    return _parseProducts(merged.values.toList());
  }

  @override
  Future<List<Product>> searchProducts(String query) async {
    final response = await _products.select().ilike('name', '%$query%');
    return _parseProducts(response);
  }

  @override
  Future<Product> getProductDetails(String id) async {
    final data = await _products.select().eq('id', id).single();
    return Product.fromJson(normalizeDynamicMap(Map<String, dynamic>.from(data)));
  }

  @override
  Future<void> addProduct(Product product) async {
    await _products.insert(product.toJson());
  }

  @override
  Future<void> updateProduct(Product product) async {
    await _products.update(product.toJson()).eq('id', product.id);
  }

  @override
  Future<void> deleteProduct(String productId) async {
    await _products.delete().eq('id', productId);
  }

  @override
  Future<void> updateStock(String productId, int quantityChange) async {
    await SupabaseService.client.rpc(
      'increment_product_stock',
      params: {'p_product_id': productId, 'p_quantity_change': quantityChange},
    );
  }

  @override
  Future<void> trackProductEvent({
    required String productId,
    required String eventType,
    String? viewerId,
  }) async {
    await SupabaseService.client.rpc(
      'track_product_event',
      params: {
        'p_product_id': productId,
        'p_event_type': eventType,
        'p_viewer_id': viewerId,
      },
    );
  }

  @override
  Future<List<Review>> getProductReviews(String productId) async {
    final response = await SupabaseService.client
        .from(SupabaseTables.reviews)
        .select()
        .eq('productId', productId)
        .order('createdAt', ascending: false);
    return response.map((item) => Review.fromMap(item)).toList();
  }

  @override
  Future<void> addReview(Review review) async {
    await SupabaseService.client.rpc(
      'add_review',
      params: {'p_review': review.toMap()},
    );
  }

  @override
  Future<bool> hasUserPurchasedProduct(String userId, String productId) async {
    final response = await SupabaseService.client
        .from(SupabaseTables.orders)
        .select('items')
        .eq('buyerId', userId)
        .inFilter('status', ['Delivered', 'Received']);

    for (final row in response) {
      final items = row['items'] as List?;
      if (items != null) {
        if (items.any((item) {
          final product = item['product'] as Map<String, dynamic>?;
          return product?['id'] == productId || item['productId'] == productId;
        })) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Future<void> reportProduct({
    required String productId,
    required String reason,
    String? details,
  }) async {
    await SupabaseService.client.rpc(
      'submit_product_report',
      params: {
        'p_product_id': productId,
        'p_reason': reason,
        'p_details': details,
      },
    );
  }
}
