import 'package:hive/hive.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';

abstract class ProductLocalDataSource {
  Future<List<Product>> getLastProducts();
  Future<void> cacheProducts(List<Product> productsToCache);
  Future<void> clearCache();
}

class ProductLocalDataSourceImpl implements ProductLocalDataSource {
  static const String _productsBoxName = 'products_box';

  @override
  Future<List<Product>> getLastProducts() async {
    final box = await Hive.openBox<Product>(_productsBoxName);
    return box.values.toList();
  }

  @override
  Future<void> cacheProducts(List<Product> productsToCache) async {
    final box = await Hive.openBox<Product>(_productsBoxName);
    await box.clear();
    await box.addAll(productsToCache);
  }

  @override
  Future<void> clearCache() async {
    final box = await Hive.openBox<Product>(_productsBoxName);
    await box.clear();
  }
}
