import 'package:dartz/dartz.dart';
import 'package:untitled1/core/error/failures.dart';
import 'package:untitled1/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';
import 'package:untitled1/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, User>> login(String email, String password) async {
    try {
      final user = await remoteDataSource.login(email, password);
      // Here you could also save the user to a LocalDataSource (Hive)
      return Right(user);
    } catch (e) {
      final message = e.toString();
      if (message.toLowerCase().contains('email not confirmed')) {
        return const Left(
          AuthFailure('Please verify your email before signing in.'),
        );
      }
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> register(
    String name,
    String email,
    String password,
    String role,
  ) async {
    try {
      final user = await remoteDataSource.register(name, email, password, role);
      return Right(user);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> signInWithGoogle() async {
    try {
      final user = await remoteDataSource.signInWithGoogle();
      return Right(user);
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('10')) {
        return const Left(
          AuthFailure(
            'Google Sign-In Error (10): Please verify your Google OAuth client IDs and Supabase Google provider configuration.',
          ),
        );
      }
      return Left(ServerFailure(errorMessage));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await remoteDataSource.logout();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final user = await remoteDataSource.getCurrentUser();
      return Right(user);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> updateUser(User user) async {
    try {
      final updatedUser = await remoteDataSource.updateUser(user);
      return Right(updatedUser);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<User>>> searchUsers(String query) async {
    try {
      final users = await remoteDataSource.searchUsers(query);
      return Right(users);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User?>> getUserById(String userId) async {
    try {
      final user = await remoteDataSource.getUserById(userId);
      return Right(user);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> sendPasswordResetEmail(String email) async {
    try {
      await remoteDataSource.sendPasswordResetEmail(email);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
