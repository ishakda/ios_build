import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:untitled1/features/cart/domain/entities/cart_item.dart';
import 'package:untitled1/features/checkout/domain/entities/order.dart';
import 'package:untitled1/features/checkout/domain/repositories/order_repository.dart';
import 'package:untitled1/features/checkout/presentation/bloc/order_bloc.dart';
import 'package:untitled1/features/checkout/presentation/bloc/order_event.dart';
import 'package:untitled1/features/checkout/presentation/bloc/order_state.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';

class _FakeOrderRepository implements OrderRepository {
  _FakeOrderRepository({
    this.buyerOrdersStream,
    this.placeOrderError,
    this.updateOrderStatusError,
  });

  final Stream<List<Order>>? buyerOrdersStream;
  final Exception? placeOrderError;
  final Exception? updateOrderStatusError;

  @override
  Stream<List<Order>> getBuyerOrders(String buyerId) {
    return buyerOrdersStream ?? const Stream.empty();
  }

  @override
  Stream<List<Order>> getVendorOrders(String vendorId) {
    return const Stream.empty();
  }

  @override
  Future<void> placeOrder(Order order) async {
    if (placeOrderError != null) {
      throw placeOrderError!;
    }
  }

  @override
  Future<void> updateOrderStatus({
    required String orderId,
    required String newStatus,
  }) async {
    if (updateOrderStatusError != null) {
      throw updateOrderStatusError!;
    }
  }

  @override
  Future<void> submitRefundRequest({
    required String orderId,
    required String reason,
    String? details,
  }) async {}
}

void main() {
  final sampleOrder = Order(
    id: 'o1',
    items: [
      CartItem(
        product: Product(
          id: 'p1',
          name: 'Phone',
          description: 'Test product',
          price: 1000,
          discountPrice: 850,
          imageUrl: 'https://example.com/image.png',
          images: const ['https://example.com/image.png'],
          rating: 4.6,
          reviewsCount: 12,
          category: 'Phones',
        ),
        quantity: 2,
      ),
    ],
    totalAmount: 1700,
    orderDate: DateTime(2026, 4, 26),
    status: 'Pending',
    buyerId: 'buyer-1',
    sellerIds: const ['seller-1'],
    orderNumber: 'ORD-202604-O1',
  );

  test('StreamBuyerOrders emits loading then loaded states', () async {
    final controller = StreamController<List<Order>>();
    final bloc = OrderBloc(
      orderRepository: _FakeOrderRepository(
        buyerOrdersStream: controller.stream,
      ),
    );

    final expectation = expectLater(
      bloc.stream,
      emitsInOrder([
        isA<OrdersLoading>(),
        isA<OrdersLoaded>().having(
          (state) => state.orders.first.id,
          'first order id',
          'o1',
        ),
      ]),
    );

    bloc.add(const StreamBuyerOrders('buyer-1'));
    controller.add([sampleOrder]);

    await expectation;
    await controller.close();
    await bloc.close();
  });

  test('stream errors emit OrderError through bloc events', () async {
    final controller = StreamController<List<Order>>();
    final bloc = OrderBloc(
      orderRepository: _FakeOrderRepository(
        buyerOrdersStream: controller.stream,
      ),
    );

    final expectation = expectLater(
      bloc.stream,
      emitsInOrder([
        isA<OrdersLoading>(),
        isA<OrderError>().having(
          (state) => state.message,
          'message',
          contains('stream failed'),
        ),
      ]),
    );

    bloc.add(const StreamBuyerOrders('buyer-1'));
    controller.addError(Exception('stream failed'));

    await expectation;
    await controller.close();
    await bloc.close();
  });

  test('PlaceOrder emits OrderError when repository throws', () async {
    final bloc = OrderBloc(
      orderRepository: _FakeOrderRepository(
        placeOrderError: Exception('checkout unavailable'),
      ),
    );

    final expectation = expectLater(
      bloc.stream,
      emits(
        isA<OrderError>().having(
          (state) => state.message,
          'message',
          contains('checkout unavailable'),
        ),
      ),
    );

    bloc.add(PlaceOrder(sampleOrder));

    await expectation;
    await bloc.close();
  });

  test('UpdateOrderStatus emits OrderError when repository throws', () async {
    final bloc = OrderBloc(
      orderRepository: _FakeOrderRepository(
        updateOrderStatusError: Exception('update failed'),
      ),
    );

    final expectation = expectLater(
      bloc.stream,
      emits(
        isA<OrderError>().having(
          (state) => state.message,
          'message',
          contains('update failed'),
        ),
      ),
    );

    bloc.add(const UpdateOrderStatus(orderId: 'o1', status: 'Cancelled'));

    await expectation;
    await bloc.close();
  });
}
