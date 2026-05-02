import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/features/vendor/domain/repositories/vendor_repository.dart';
import 'package:untitled1/features/vendor/presentation/cubit/vendor_orders_state.dart';

class VendorOrdersCubit extends Cubit<VendorOrdersState> {
  VendorOrdersCubit({required this.vendorRepository})
    : super(const VendorOrdersState());

  final VendorRepository vendorRepository;
  StreamSubscription? _subscription;

  Future<void> loadOrders(String vendorId) async {
    emit(
      state.copyWith(
        isLoading: true,
        clearErrorMessage: true,
        clearActionErrorMessage: true,
      ),
    );
    await _subscription?.cancel();
    _subscription = vendorRepository
        .watchVendorOrders(vendorId)
        .listen(
          (orders) {
            emit(
              state.copyWith(
                isLoading: false,
                orders: orders,
                clearErrorMessage: true,
              ),
            );
          },
          onError: (_) {
            emit(
              state.copyWith(
                isLoading: false,
                errorMessage:
                    'We could not load store orders right now. Please try again later.',
              ),
            );
          },
        );
  }

  void updateFilter(String filter) {
    emit(state.copyWith(selectedFilter: filter, clearActionErrorMessage: true));
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String buyerId,
    required String newStatus,
  }) async {
    emit(state.copyWith(isUpdating: true, clearActionErrorMessage: true));
    try {
      await vendorRepository.updateOrderStatus(
        orderId: orderId,
        buyerId: buyerId,
        newStatus: newStatus,
      );
      emit(state.copyWith(isUpdating: false, clearActionErrorMessage: true));
    } catch (_) {
      emit(
        state.copyWith(
          isUpdating: false,
          actionErrorMessage: 'Unable to update this order right now.',
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
