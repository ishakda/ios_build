import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:untitled1/features/cart/domain/entities/cart_item.dart';
import 'package:untitled1/features/checkout/domain/entities/order.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';
import 'package:untitled1/features/vendor/domain/repositories/vendor_repository.dart';
import 'package:untitled1/features/vendor/presentation/cubit/vendor_orders_cubit.dart';
import 'package:untitled1/features/vendor/presentation/cubit/vendor_orders_state.dart';

class _FakeVendorRepository implements VendorRepository {
  _FakeVendorRepository({this.ordersStream, this.updateOrderStatusError});

  final Stream<List<Order>>? ordersStream;
  final Exception? updateOrderStatusError;

  @override
  Stream<List<Order>> watchVendorOrders(String vendorId) {
    return ordersStream ?? const Stream.empty();
  }

  @override
  Future<void> updateOrderStatus({
    required String orderId,
    required String buyerId,
    required String newStatus,
  }) async {
    if (updateOrderStatusError != null) {
      throw updateOrderStatusError!;
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
      status: 'Pending',
      buyerId: 'buyer-1',
      orderNumber: 'ORD-202604-O1',
    ),
    Order(
      id: 'o2',
      items: [CartItem(product: product, quantity: 2)],
      totalAmount: 80,
      orderDate: DateTime(2026, 4, 26, 12),
      status: 'Shipped',
      buyerId: 'buyer-2',
      orderNumber: 'ORD-202604-O2',
    ),
  ];

  test('loadOrders stores incoming orders and supports filtering', () async {
    final controller = StreamController<List<Order>>();
    final cubit = VendorOrdersCubit(
      vendorRepository: _FakeVendorRepository(ordersStream: controller.stream),
    );

    final expectation = expectLater(
      cubit.stream,
      emitsThrough(
        isA<VendorOrdersState>().having(
          (state) => state.orders.length,
          'order count',
          2,
        ),
      ),
    );

    await cubit.loadOrders('seller-1');
    controller.add(orders);

    await expectation;
    cubit.updateFilter('Shipped');

    expect(cubit.state.selectedFilter, 'Shipped');
    expect(cubit.state.filteredOrders.length, 1);
    expect(cubit.state.filteredOrders.first.id, 'o2');

    await controller.close();
    await cubit.close();
  });

  test(
    'updateOrderStatus emits an action error when repository throws',
    () async {
      final cubit = VendorOrdersCubit(
        vendorRepository: _FakeVendorRepository(
          updateOrderStatusError: Exception('write failed'),
        ),
      );

      final expectation = expectLater(
        cubit.stream,
        emitsInOrder([
          isA<VendorOrdersState>().having(
            (state) => state.isUpdating,
            'is updating',
            true,
          ),
          isA<VendorOrdersState>()
              .having((state) => state.isUpdating, 'is updating', false)
              .having(
                (state) => state.actionErrorMessage,
                'message',
                'Unable to update this order right now.',
              ),
        ]),
      );

      await cubit.updateOrderStatus(
        orderId: 'o1',
        buyerId: 'buyer-1',
        newStatus: 'Shipped',
      );

      await expectation;
      await cubit.close();
    },
  );
}
