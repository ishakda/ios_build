import 'package:equatable/equatable.dart';
import 'package:untitled1/features/checkout/domain/entities/order.dart';

class VendorOrdersState extends Equatable {
  const VendorOrdersState({
    this.isLoading = true,
    this.isUpdating = false,
    this.selectedFilter = 'All',
    this.orders = const [],
    this.errorMessage,
    this.actionErrorMessage,
  });

  final bool isLoading;
  final bool isUpdating;
  final String selectedFilter;
  final List<Order> orders;
  final String? errorMessage;
  final String? actionErrorMessage;

  List<Order> get filteredOrders {
    if (selectedFilter == 'All') {
      return orders;
    }
    return orders.where((order) => order.status == selectedFilter).toList();
  }

  VendorOrdersState copyWith({
    bool? isLoading,
    bool? isUpdating,
    String? selectedFilter,
    List<Order>? orders,
    String? errorMessage,
    String? actionErrorMessage,
    bool clearErrorMessage = false,
    bool clearActionErrorMessage = false,
  }) {
    return VendorOrdersState(
      isLoading: isLoading ?? this.isLoading,
      isUpdating: isUpdating ?? this.isUpdating,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      orders: orders ?? this.orders,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      actionErrorMessage: clearActionErrorMessage
          ? null
          : actionErrorMessage ?? this.actionErrorMessage,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isUpdating,
    selectedFilter,
    orders,
    errorMessage,
    actionErrorMessage,
  ];
}
