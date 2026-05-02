import 'package:equatable/equatable.dart';
import 'package:untitled1/features/vendor/domain/entities/vendor_store_view.dart';

class VendorStoreState extends Equatable {
  const VendorStoreState({
    this.isLoading = true,
    this.isSaving = false,
    this.view,
    this.errorMessage,
    this.actionErrorMessage,
  });

  final bool isLoading;
  final bool isSaving;
  final VendorStoreView? view;
  final String? errorMessage;
  final String? actionErrorMessage;

  VendorStoreState copyWith({
    bool? isLoading,
    bool? isSaving,
    VendorStoreView? view,
    String? errorMessage,
    String? actionErrorMessage,
    bool clearErrorMessage = false,
    bool clearActionErrorMessage = false,
  }) {
    return VendorStoreState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      view: view ?? this.view,
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
    isSaving,
    view,
    errorMessage,
    actionErrorMessage,
  ];
}
