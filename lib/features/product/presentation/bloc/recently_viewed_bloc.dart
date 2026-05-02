import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';
import 'recently_viewed_event.dart';
import 'recently_viewed_state.dart';

class RecentlyViewedBloc
    extends Bloc<RecentlyViewedEvent, RecentlyViewedState> {
  final Box<Product> _recentlyViewedBox = Hive.box<Product>('recently_viewed');
  static const int _maxItems = 10;

  RecentlyViewedBloc() : super(const RecentlyViewedState()) {
    on<LoadRecentlyViewed>(_onLoadRecentlyViewed);
    on<AddToRecentlyViewed>(_onAddToRecentlyViewed);

    add(LoadRecentlyViewed());
  }

  void _onLoadRecentlyViewed(
    LoadRecentlyViewed event,
    Emitter<RecentlyViewedState> emit,
  ) {
    final items = _recentlyViewedBox.values.toList().reversed.toList();
    emit(RecentlyViewedState(items: items));
  }

  void _onAddToRecentlyViewed(
    AddToRecentlyViewed event,
    Emitter<RecentlyViewedState> emit,
  ) {
    // Use ID-based keys for consistency
    _recentlyViewedBox.put(event.product.id, event.product);

    final items = _recentlyViewedBox.values.toList().reversed.toList();

    // Limit size in the list and box
    if (items.length > _maxItems) {
      final itemsToRemove = items.sublist(_maxItems);
      for (var item in itemsToRemove) {
        _recentlyViewedBox.delete(item.id);
      }
    }

    emit(
      RecentlyViewedState(
        items: _recentlyViewedBox.values.toList().reversed.toList(),
      ),
    );
  }
}
