import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:untitled1/core/error/failures.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';
import 'package:untitled1/features/auth/domain/repositories/auth_repository.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_event.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_state.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.currentUser, this.currentUserResult});

  final User? currentUser;
  final Either<Failure, User?>? currentUserResult;

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    return currentUserResult ?? Right(currentUser);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final signedInUser = User(
    id: 'u1',
    name: 'Test User',
    email: 'test@example.com',
  );

  test(
    'AuthCheckRequested emits Authenticated when a session exists',
    () async {
      final bloc = AuthBloc(
        authRepository: _FakeAuthRepository(currentUser: signedInUser),
      );

      bloc.add(AuthCheckRequested());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AuthChecking>(),
          isA<Authenticated>().having(
            (state) => state.user.email,
            'email',
            'test@example.com',
          ),
        ]),
      );

      await bloc.close();
    },
  );

  test(
    'AuthCheckRequested emits Unauthenticated when no session exists',
    () async {
      final bloc = AuthBloc(
        authRepository: _FakeAuthRepository(currentUser: null),
      );

      bloc.add(AuthCheckRequested());

      await expectLater(
        bloc.stream,
        emitsInOrder([isA<AuthChecking>(), isA<Unauthenticated>()]),
      );

      await bloc.close();
    },
  );

  test(
    'AuthCheckRequested emits Unauthenticated when session lookup fails',
    () async {
      final bloc = AuthBloc(
        authRepository: _FakeAuthRepository(
          currentUserResult: const Left(ServerFailure('lookup failed')),
        ),
      );

      bloc.add(AuthCheckRequested());

      await expectLater(
        bloc.stream,
        emitsInOrder([isA<AuthChecking>(), isA<Unauthenticated>()]),
      );

      await bloc.close();
    },
  );

  test(
    'SessionUserUpdated emits Authenticated with the updated user',
    () async {
      final updatedUser = signedInUser.copyWith(name: 'Updated Name');
      final bloc = AuthBloc(
        authRepository: _FakeAuthRepository(currentUser: signedInUser),
      );

      bloc.add(SessionUserUpdated(updatedUser));

      await expectLater(
        bloc.stream,
        emits(
          isA<Authenticated>().having(
            (state) => state.user.name,
            'name',
            'Updated Name',
          ),
        ),
      );

      await bloc.close();
    },
  );
}
