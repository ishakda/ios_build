import 'package:equatable/equatable.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class LoginSubmitted extends AuthEvent {
  final String email;
  final String password;

  const LoginSubmitted({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class RegisterSubmitted extends AuthEvent {
  final String name;
  final String email;
  final String password;
  final String role;

  const RegisterSubmitted({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
  });

  @override
  List<Object?> get props => [name, email, password, role];
}

class GoogleSignInRequested extends AuthEvent {}

class LogoutRequested extends AuthEvent {}

class AuthCheckRequested extends AuthEvent {}

class PasswordResetRequested extends AuthEvent {
  final String email;

  const PasswordResetRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

class SessionUserUpdated extends AuthEvent {
  const SessionUserUpdated(this.user);

  final User user;

  @override
  List<Object?> get props => [user];
}
