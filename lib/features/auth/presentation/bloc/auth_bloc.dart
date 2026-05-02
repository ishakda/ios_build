import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/core/services/onesignal_service.dart';
import 'package:untitled1/features/auth/domain/repositories/auth_repository.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_event.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<LoginSubmitted>(_onLoginSubmitted);
    on<RegisterSubmitted>(_onRegisterSubmitted);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<SessionUserUpdated>(_onSessionUserUpdated);
    on<PasswordResetRequested>(_onPasswordResetRequested);
  }

  Future<void> _onPasswordResetRequested(
    PasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await authRepository.sendPasswordResetEmail(event.email);
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(PasswordResetEmailSent()),
    );
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await authRepository.login(event.email, event.password);
    result.fold((failure) => emit(AuthError(failure.message)), (user) {
      OneSignalService.setExternalUserId(user.id);
      emit(Authenticated(user));
    });
  }

  Future<void> _onRegisterSubmitted(
    RegisterSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await authRepository.register(
      event.name,
      event.email,
      event.password,
      event.role,
    );
    result.fold(
      (failure) {
        final message = failure.message;
        if (message.toLowerCase().contains('verify your email')) {
          emit(RegistrationVerificationRequired(message));
          return;
        }
        emit(AuthError(message));
      },
      (user) {
        OneSignalService.setExternalUserId(user.id);
        emit(Authenticated(user));
      },
    );
  }

  Future<void> _onGoogleSignInRequested(
    GoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await authRepository.signInWithGoogle();
    result.fold((failure) => emit(AuthError(failure.message)), (user) {
      OneSignalService.setExternalUserId(user.id);
      emit(Authenticated(user));
    });
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await authRepository.logout();
    result.fold((failure) => emit(AuthError(failure.message)), (_) {
      OneSignalService.logout();
      emit(Unauthenticated());
    });
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthChecking());
    final result = await authRepository.getCurrentUser();
    result.fold((_) => emit(Unauthenticated()), (user) {
      if (user != null) {
        OneSignalService.setExternalUserId(user.id);
        emit(Authenticated(user));
      } else {
        OneSignalService.logout();
        emit(Unauthenticated());
      }
    });
  }

  void _onSessionUserUpdated(
    SessionUserUpdated event,
    Emitter<AuthState> emit,
  ) {
    OneSignalService.setExternalUserId(event.user.id);
    emit(Authenticated(event.user));
  }
}
