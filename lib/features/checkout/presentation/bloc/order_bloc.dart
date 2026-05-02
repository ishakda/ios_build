import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/features/checkout/domain/repositories/order_repository.dart';
import 'order_event.dart';
import 'order_state.dart';

class OrderBloc extends Bloc<OrderEvent, OrderState> {
  final OrderRepository orderRepository;
  StreamSubscription? _ordersSubscription;

  OrderBloc({required this.orderRepository}) : super(OrdersInitial()) {
    on<StreamBuyerOrders>(_onStreamBuyerOrders);
    on<StreamVendorOrders>(_onStreamVendorOrders);
    on<OrdersUpdated>(_onOrdersUpdated);
    on<OrderStreamFailed>(_onOrderStreamFailed);
    on<PlaceOrder>(_onPlaceOrder);
    on<UpdateOrderStatus>(_onUpdateOrderStatus);
  }

  Future<void> _onStreamBuyerOrders(
    StreamBuyerOrders event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrdersLoading());
    await _ordersSubscription?.cancel();
    _ordersSubscription = orderRepository
        .getBuyerOrders(event.buyerId)
        .listen(
          (orders) => add(OrdersUpdated(orders)),
          onError: (error) => add(OrderStreamFailed(error.toString())),
        );
  }

  Future<void> _onStreamVendorOrders(
    StreamVendorOrders event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrdersLoading());
    await _ordersSubscription?.cancel();
    _ordersSubscription = orderRepository
        .getVendorOrders(event.vendorId)
        .listen(
          (orders) => add(OrdersUpdated(orders)),
          onError: (error) => add(OrderStreamFailed(error.toString())),
        );
  }

  void _onOrdersUpdated(OrdersUpdated event, Emitter<OrderState> emit) {
    emit(OrdersLoaded(event.orders));
  }

  void _onOrderStreamFailed(OrderStreamFailed event, Emitter<OrderState> emit) {
    emit(OrderError(event.message));
  }

  Future<void> _onPlaceOrder(PlaceOrder event, Emitter<OrderState> emit) async {
    try {
      await orderRepository.placeOrder(event.order);
      // No need to manually reload, the stream will handle it
    } catch (e) {
      emit(OrderError(e.toString()));
    }
  }

  Future<void> _onUpdateOrderStatus(
    UpdateOrderStatus event,
    Emitter<OrderState> emit,
  ) async {
    try {
      await orderRepository.updateOrderStatus(
        orderId: event.orderId,
        newStatus: event.status,
      );
    } catch (e) {
      emit(OrderError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _ordersSubscription?.cancel();
    return super.close();
  }
}
