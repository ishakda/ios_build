import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:untitled1/core/error/failures.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';
import 'package:untitled1/features/auth/domain/repositories/auth_repository.dart';
import 'package:untitled1/features/auth/presentation/cubit/profile_update_cubit.dart';
import 'package:untitled1/features/auth/presentation/cubit/profile_update_state.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.updateUserResult});

  final Either<Failure, User>? updateUserResult;

  @override
  Future<Either<Failure, User>> updateUser(User user) async {
    return updateUserResult ?? Right(user);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final user = User(id: 'u1', name: 'Test User', email: 'test@example.com');

  test('updateUser emits submitting then success', () async {
    final updatedUser = user.copyWith(name: 'Updated Name');
    final cubit = ProfileUpdateCubit(
      authRepository: _FakeAuthRepository(updateUserResult: Right(updatedUser)),
    );

    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<ProfileUpdateSubmitting>(),
        isA<ProfileUpdateSuccess>().having(
          (state) => state.user.name,
          'name',
          'Updated Name',
        ),
      ]),
    );

    await cubit.updateUser(user);

    await expectation;
    await cubit.close();
  });

  test('updateUser emits failure when repository returns an error', () async {
    final cubit = ProfileUpdateCubit(
      authRepository: _FakeAuthRepository(
        updateUserResult: const Left(ServerFailure('update failed')),
      ),
    );

    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<ProfileUpdateSubmitting>(),
        isA<ProfileUpdateFailure>().having(
          (state) => state.message,
          'message',
          'update failed',
        ),
      ]),
    );

    await cubit.updateUser(user);

    await expectation;
    await cubit.close();
  });
}
