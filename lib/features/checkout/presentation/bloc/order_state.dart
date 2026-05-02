import 'package:equatable/equatable.dart';
import 'package:untitled1/features/checkout/domain/entities/order.dart';

abstract class OrderState extends Equatable {
  const OrderState();

  @override
  List<Object> get props => [];
}

class OrdersInitial extends OrderState {}

class OrdersLoading extends OrderState {}

class OrdersLoaded extends OrderState {
  final List<Order> orders;
  const OrdersLoaded(this.orders);

  @override
  List<Object> get props => [orders];
}

class OrderError extends OrderState {
  final String message;
  const OrderError(this.message);

  @override
  List<Object> get props => [message];
}
