import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/features/auth/domain/repositories/auth_repository.dart';
import 'package:untitled1/features/auth/presentation/cubit/user_search_state.dart';

class UserSearchCubit extends Cubit<UserSearchState> {
  UserSearchCubit({required this.authRepository}) : super(UserSearchInitial());

  final AuthRepository authRepository;

  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      emit(UserSearchInitial());
      return;
    }

    emit(UserSearchLoading());
    final result = await authRepository.searchUsers(trimmed);
    result.fold(
      (failure) => emit(UserSearchFailure(failure.message)),
      (users) => emit(UserSearchSuccess(users)),
    );
  }

  void reset() {
    emit(UserSearchInitial());
  }
}
