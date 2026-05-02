import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';
import 'wishlist_event.dart';
import 'wishlist_state.dart';

class WishlistBloc extends Bloc<WishlistEvent, WishlistState> {
  final Box<Product> _wishlistBox = Hive.box<Product>('wishlist');

  WishlistBloc() : super(const WishlistState()) {
    on<LoadWishlist>(_onLoadWishlist);
    on<ToggleWishlist>(_onToggleWishlist);

    add(LoadWishlist());
  }

  void _onLoadWishlist(LoadWishlist event, Emitter<WishlistState> emit) {
    final items = _wishlistBox.values.toList();
    emit(WishlistState(items: items));
  }

  void _onToggleWishlist(ToggleWishlist event, Emitter<WishlistState> emit) {
    if (_wishlistBox.containsKey(event.product.id)) {
      _wishlistBox.delete(event.product.id);
    } else {
      _wishlistBox.put(event.product.id, event.product);
    }
    emit(WishlistState(items: _wishlistBox.values.toList()));
  }
}
