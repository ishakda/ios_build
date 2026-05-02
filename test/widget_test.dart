import 'package:flutter_test/flutter_test.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';

void main() {
  test('User.fromMap and copyWith preserve core identity data', () {
    final user = User.fromMap({
      'id': 'u1',
      'name': 'Original Name',
      'email': 'original@example.com',
      'role': 'buyer',
    });

    final updated = user.copyWith(
      name: 'Updated Name',
      phoneNumber: '+213555000111',
    );

    expect(user.id, 'u1');
    expect(user.email, 'original@example.com');
    expect(updated.id, 'u1');
    expect(updated.email, 'original@example.com');
    expect(updated.name, 'Updated Name');
    expect(updated.phoneNumber, '+213555000111');
    expect(updated.role, 'buyer');
  });
}
