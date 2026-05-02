import 'package:flutter_test/flutter_test.dart';
import 'package:untitled1/features/cart/domain/entities/cart_item.dart';
import 'package:untitled1/features/cart/presentation/bloc/cart_state.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';

void main() {
  test('totalPrice prefers discountPrice and totalItems sums quantities', () {
    final discountedProduct = Product(
      id: 'p1',
      name: 'Discounted Phone',
      description: 'Discounted product',
      price: 1000,
      discountPrice: 850,
      imageUrl: 'https://example.com/discounted.png',
      images: const ['https://example.com/discounted.png'],
      rating: 4.5,
      reviewsCount: 20,
      category: 'Phones',
    );
    final regularProduct = Product(
      id: 'p2',
      name: 'Case',
      description: 'Regular product',
      price: 100,
      imageUrl: 'https://example.com/case.png',
      images: const ['https://example.com/case.png'],
      rating: 4.2,
      reviewsCount: 5,
      category: 'Accessories',
    );

    final state = CartState(
      items: [
        CartItem(product: discountedProduct, quantity: 2),
        CartItem(product: regularProduct, quantity: 3),
      ],
    );

    expect(state.totalPrice, 2000);
    expect(state.totalItems, 5);
  });
}
