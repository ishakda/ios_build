import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:untitled1/features/cart/domain/entities/cart_item.dart';
import 'cart_event.dart';
import 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  final Box<CartItem> _cartBox = Hive.box<CartItem>('cart');

  CartBloc() : super(const CartState()) {
    on<LoadCart>(_onLoadCart);
    on<AddToCart>(_onAddToCart);
    on<RemoveFromCart>(_onRemoveFromCart);
    on<UpdateQuantity>(_onUpdateQuantity);
    on<ClearCart>(_onClearCart);

    add(LoadCart());
  }

  void _onLoadCart(LoadCart event, Emitter<CartState> emit) {
    final items = _cartBox.values.toList();
    emit(CartState(items: items));
  }

  void _onClearCart(ClearCart event, Emitter<CartState> emit) {
    _cartBox.clear();
    emit(const CartState(items: []));
  }

  void _onAddToCart(AddToCart event, Emitter<CartState> emit) {
    final updatedItems = List<CartItem>.from(state.items);
    final index = updatedItems.indexWhere(
      (item) => item.product.id == event.product.id,
    );

    if (index >= 0) {
      updatedItems[index] = updatedItems[index].copyWith(
        quantity: updatedItems[index].quantity + 1,
      );
    } else {
      updatedItems.add(CartItem(product: event.product, quantity: 1));
    }

    _saveToHive(updatedItems);
    emit(CartState(items: updatedItems));
  }

  void _onRemoveFromCart(RemoveFromCart event, Emitter<CartState> emit) {
    final updatedItems = state.items
        .where((item) => item.product.id != event.productId)
        .toList();
    _saveToHive(updatedItems);
    emit(CartState(items: updatedItems));
  }

  void _onUpdateQuantity(UpdateQuantity event, Emitter<CartState> emit) {
    final updatedItems = List<CartItem>.from(state.items);
    final index = updatedItems.indexWhere(
      (item) => item.product.id == event.productId,
    );

    if (index >= 0) {
      final newQuantity = updatedItems[index].quantity + event.delta;
      if (newQuantity > 0) {
        updatedItems[index] = updatedItems[index].copyWith(
          quantity: newQuantity,
        );
        _saveToHive(updatedItems);
        emit(CartState(items: updatedItems));
      } else {
        add(RemoveFromCart(event.productId));
      }
    }
  }

  void _saveToHive(List<CartItem> items) {
    _cartBox.clear();
    for (var item in items) {
      _cartBox.add(item);
    }
  }
}
