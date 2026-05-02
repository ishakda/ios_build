import 'package:equatable/equatable.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthChecking extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final User user;
  const Authenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class Unauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class RegistrationVerificationRequired extends AuthState {
  final String message;
  const RegistrationVerificationRequired(this.message);

  @override
  List<Object?> get props => [message];
}

class PasswordResetEmailSent extends AuthState {}
