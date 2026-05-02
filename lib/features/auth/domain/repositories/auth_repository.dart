import 'package:dartz/dartz.dart';
import 'package:untitled1/core/error/failures.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> login(String email, String password);
  Future<Either<Failure, User>> register(
    String name,
    String email,
    String password,
    String role,
  );
  Future<Either<Failure, User>> signInWithGoogle();
  Future<Either<Failure, void>> logout();
  Future<Either<Failure, User?>> getCurrentUser();
  Future<Either<Failure, User>> updateUser(User user);
  Future<Either<Failure, List<User>>> searchUsers(String query);
  Future<Either<Failure, User?>> getUserById(String userId);
  Future<Either<Failure, void>> sendPasswordResetEmail(String email);
}
