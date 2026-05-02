import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:untitled1/features/cart/domain/entities/cart_item.dart';
import 'package:untitled1/features/checkout/domain/entities/order.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';
import 'package:untitled1/features/vendor/domain/repositories/vendor_repository.dart';
import 'package:untitled1/features/vendor/presentation/cubit/vendor_store_cubit.dart';
import 'package:untitled1/features/vendor/presentation/cubit/vendor_store_state.dart';

class _FakeVendorRepository implements VendorRepository {
  _FakeVendorRepository({
    this.profileStream,
    this.productsStream,
    this.ordersStream,
    this.updateStoreInfoError,
  });

  final Stream<Map<String, dynamic>?>? profileStream;
  final Stream<List<Product>>? productsStream;
  final Stream<List<Order>>? ordersStream;
  final Exception? updateStoreInfoError;

  @override
  Stream<Map<String, dynamic>?> watchStoreProfile(String vendorId) {
    return profileStream ?? const Stream.empty();
  }

  @override
  Stream<List<Product>> watchStoreProducts(String vendorId) {
    return productsStream ?? const Stream.empty();
  }

  @override
  Stream<List<Order>> watchVendorOrders(String vendorId) {
    return ordersStream ?? const Stream.empty();
  }

  @override
  Future<void> updateStoreInfo({
    required String vendorId,
    required String storeName,
    required String storeDescription,
  }) async {
    if (updateStoreInfoError != null) {
      throw updateStoreInfoError!;
    }
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final product = Product(
    id: 'p1',
    name: 'Speaker',
    description: 'Portable speaker',
    price: 40,
    imageUrl: 'https://example.com/speaker.png',
    images: const ['https://example.com/speaker.png'],
    rating: 4.5,
    reviewsCount: 3,
    category: 'Audio',
    sellerId: 'seller-1',
  );

  final orders = [
    Order(
      id: 'o1',
      items: [CartItem(product: product, quantity: 1)],
      totalAmount: 40,
      orderDate: DateTime(2026, 4, 26, 10),
      status: 'Delivered',
      buyerId: 'buyer-1',
      orderNumber: 'ORD-202604-O1',
    ),
    Order(
      id: 'o2',
      items: [CartItem(product: product, quantity: 2)],
      totalAmount: 80,
      orderDate: DateTime(2026, 4, 26, 12),
      status: 'Pending',
      buyerId: 'buyer-2',
      orderNumber: 'ORD-202604-O2',
    ),
  ];

  test('loadStore combines profile, products, and seller insights', () async {
    final profileController = StreamController<Map<String, dynamic>?>();
    final productsController = StreamController<List<Product>>();
    final ordersController = StreamController<List<Order>>();
    final cubit = VendorStoreCubit(
      vendorRepository: _FakeVendorRepository(
        profileStream: profileController.stream,
        productsStream: productsController.stream,
        ordersStream: ordersController.stream,
      ),
    );

    final expectation = expectLater(
      cubit.stream,
      emitsThrough(
        isA<VendorStoreState>()
            .having((state) => state.view?.storeName, 'store name', 'Sound Lab')
            .having((state) => state.view?.products.length, 'product count', 1)
            .having(
              (state) => state.view?.completedOrders,
              'completed orders',
              1,
            )
            .having((state) => state.view?.pendingOrders, 'pending orders', 1)
            .having(
              (state) => state.view?.totalEarnings,
              'total earnings',
              40.0,
            ),
      ),
    );

    await cubit.loadStore(
      vendorId: 'seller-1',
      fallbackStoreName: 'Fallback Store',
      includeInsights: true,
    );
    profileController.add({
      'storeName': 'Sound Lab',
      'storeDescription': 'Portable audio gear',
    });
    productsController.add([product]);
    ordersController.add(orders);

    await expectation;

    await profileController.close();
    await productsController.close();
    await ordersController.close();
    await cubit.close();
  });

  test(
    'updateStoreInfo emits an action error when repository throws',
    () async {
      final cubit = VendorStoreCubit(
        vendorRepository: _FakeVendorRepository(
          updateStoreInfoError: Exception('write failed'),
        ),
      );

      await cubit.loadStore(
        vendorId: 'seller-1',
        fallbackStoreName: 'Fallback Store',
        includeInsights: false,
      );

      final expectation = expectLater(
        cubit.stream,
        emitsInOrder([
          isA<VendorStoreState>().having(
            (state) => state.isSaving,
            'is saving',
            true,
          ),
          isA<VendorStoreState>()
              .having((state) => state.isSaving, 'is saving', false)
              .having(
                (state) => state.actionErrorMessage,
                'message',
                'Unable to update store details right now.',
              ),
        ]),
      );

      await cubit.updateStoreInfo(
        storeName: 'Updated Store',
        storeDescription: 'Updated description',
      );

      await expectation;
      await cubit.close();
    },
  );
}
