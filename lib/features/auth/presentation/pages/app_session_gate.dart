import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_state.dart';
import 'package:untitled1/features/auth/presentation/pages/login_page.dart';
import 'package:untitled1/features/main_navigation_container.dart';
import 'package:untitled1/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:untitled1/features/splash/presentation/pages/splash_screen.dart';

class AppSessionGate extends StatefulWidget {
  const AppSessionGate({
    super.key,
    this.splashBuilder,
    this.authenticatedBuilder,
    this.loginBuilder,
    this.onboardingBuilder,
  });

  final WidgetBuilder? splashBuilder;
  final WidgetBuilder? authenticatedBuilder;
  final WidgetBuilder? loginBuilder;
  final Widget Function(
    BuildContext context,
    Future<void> Function() onFinished,
  )?
  onboardingBuilder;

  @override
  State<AppSessionGate> createState() => _AppSessionGateState();
}

class _AppSessionGateState extends State<AppSessionGate> {
  static const _onboardingCompletedKey = 'onboarding_completed';

  late bool _hasCompletedOnboarding;
  bool _isSessionResolved = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    final settingsBox = Hive.box('settings');
    _hasCompletedOnboarding =
        settingsBox.get(_onboardingCompletedKey, defaultValue: false)
            as bool? ??
        false;
  }

  Future<void> _completeOnboarding() async {
    await Hive.box('settings').put(_onboardingCompletedKey, true);
    if (!mounted) {
      return;
    }
    setState(() {
      _hasCompletedOnboarding = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current is AuthChecking ||
          current is Authenticated ||
          current is Unauthenticated,
      listener: (context, state) {
        if (state is AuthChecking) {
          setState(() {
            _isSessionResolved = false;
          });
          return;
        }

        if (state is Authenticated) {
          setState(() {
            _isSessionResolved = true;
            _isAuthenticated = true;
          });
          return;
        }

        if (state is Unauthenticated) {
          setState(() {
            _isSessionResolved = true;
            _isAuthenticated = false;
          });
        }
      },
      builder: (context, state) {
        if (!_isSessionResolved ||
            state is AuthInitial ||
            state is AuthChecking) {
          return widget.splashBuilder?.call(context) ??
              const SplashScreen(isLoading: true);
        }

        if (_isAuthenticated) {
          return widget.authenticatedBuilder?.call(context) ??
              const MainNavigationContainer();
        }

        if (!_hasCompletedOnboarding) {
          return widget.onboardingBuilder?.call(context, _completeOnboarding) ??
              OnboardingPage(onFinished: _completeOnboarding);
        }

        return widget.loginBuilder?.call(context) ?? const LoginPage();
      },
    );
  }
}
