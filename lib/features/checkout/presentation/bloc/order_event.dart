import 'package:equatable/equatable.dart';
import 'package:untitled1/features/checkout/domain/entities/order.dart';

abstract class OrderEvent extends Equatable {
  const OrderEvent();

  @override
  List<Object?> get props => [];
}

class LoadOrders extends OrderEvent {}

class StreamBuyerOrders extends OrderEvent {
  final String buyerId;
  const StreamBuyerOrders(this.buyerId);

  @override
  List<Object?> get props => [buyerId];
}

class StreamVendorOrders extends OrderEvent {
  final String vendorId;
  const StreamVendorOrders(this.vendorId);

  @override
  List<Object?> get props => [vendorId];
}

class OrdersUpdated extends OrderEvent {
  final List<Order> orders;
  const OrdersUpdated(this.orders);

  @override
  List<Object?> get props => [orders];
}

class OrderStreamFailed extends OrderEvent {
  final String message;

  const OrderStreamFailed(this.message);

  @override
  List<Object?> get props => [message];
}

class PlaceOrder extends OrderEvent {
  final Order order;
  const PlaceOrder(this.order);

  @override
  List<Object?> get props => [order];
}

class UpdateOrderStatus extends OrderEvent {
  final String orderId;
  final String status;

  const UpdateOrderStatus({required this.orderId, required this.status});

  @override
  List<Object?> get props => [orderId, status];
}
