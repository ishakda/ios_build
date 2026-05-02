import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:untitled1/core/error/failures.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';
import 'package:untitled1/features/auth/domain/repositories/auth_repository.dart';
import 'package:untitled1/features/auth/presentation/cubit/user_search_cubit.dart';
import 'package:untitled1/features/auth/presentation/cubit/user_search_state.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.searchUsersResult});

  final Either<Failure, List<User>>? searchUsersResult;

  @override
  Future<Either<Failure, List<User>>> searchUsers(String query) async {
    return searchUsersResult ?? const Right(<User>[]);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final users = [User(id: 'u1', name: 'Ali Seller', email: 'ali@example.com')];

  test('search emits loading then success', () async {
    final cubit = UserSearchCubit(
      authRepository: _FakeAuthRepository(searchUsersResult: Right(users)),
    );

    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<UserSearchLoading>(),
        isA<UserSearchSuccess>().having(
          (state) => state.users.first.id,
          'first user id',
          'u1',
        ),
      ]),
    );

    await cubit.search('ali');

    await expectation;
    await cubit.close();
  });

  test('search emits failure when repository returns an error', () async {
    final cubit = UserSearchCubit(
      authRepository: _FakeAuthRepository(
        searchUsersResult: const Left(ServerFailure('search failed')),
      ),
    );

    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<UserSearchLoading>(),
        isA<UserSearchFailure>().having(
          (state) => state.message,
          'message',
          'search failed',
        ),
      ]),
    );

    await cubit.search('ali');

    await expectation;
    await cubit.close();
  });

  test('blank search resets to initial state', () async {
    final cubit = UserSearchCubit(
      authRepository: _FakeAuthRepository(searchUsersResult: Right(users)),
    );

    await cubit.search('ali');
    cubit.reset();

    expect(cubit.state, isA<UserSearchInitial>());
    await cubit.close();
  });
}
