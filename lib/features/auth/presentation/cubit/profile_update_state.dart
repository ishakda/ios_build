import 'package:equatable/equatable.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';

abstract class ProfileUpdateState extends Equatable {
  const ProfileUpdateState();

  @override
  List<Object?> get props => [];
}

class ProfileUpdateInitial extends ProfileUpdateState {}

class ProfileUpdateSubmitting extends ProfileUpdateState {}

class ProfileUpdateSuccess extends ProfileUpdateState {
  const ProfileUpdateSuccess(this.user);

  final User user;

  @override
  List<Object?> get props => [user];
}

class ProfileUpdateFailure extends ProfileUpdateState {
  const ProfileUpdateFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
