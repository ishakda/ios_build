import 'package:equatable/equatable.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';

abstract class UserSearchState extends Equatable {
  const UserSearchState();

  @override
  List<Object?> get props => [];
}

class UserSearchInitial extends UserSearchState {}

class UserSearchLoading extends UserSearchState {}

class UserSearchSuccess extends UserSearchState {
  const UserSearchSuccess(this.users);

  final List<User> users;

  @override
  List<Object?> get props => [users];
}

class UserSearchFailure extends UserSearchState {
  const UserSearchFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
