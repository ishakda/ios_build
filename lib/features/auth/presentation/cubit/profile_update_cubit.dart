import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';
import 'package:untitled1/features/auth/domain/repositories/auth_repository.dart';
import 'package:untitled1/features/auth/presentation/cubit/profile_update_state.dart';

class ProfileUpdateCubit extends Cubit<ProfileUpdateState> {
  ProfileUpdateCubit({required this.authRepository})
    : super(ProfileUpdateInitial());

  final AuthRepository authRepository;

  Future<void> updateUser(User user) async {
    emit(ProfileUpdateSubmitting());
    final result = await authRepository.updateUser(user);
    result.fold(
      (failure) => emit(ProfileUpdateFailure(failure.message)),
      (updatedUser) => emit(ProfileUpdateSuccess(updatedUser)),
    );
  }

  void reset() {
    emit(ProfileUpdateInitial());
  }
}
