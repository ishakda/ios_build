import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/localization/localized_error_message.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:untitled1/core/widgets/app_page_intro_card.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_event.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_state.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedRole = 'buyer';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
        RegisterSubmitted(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          role: _selectedRole,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else if (state is RegistrationVerificationRequired) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizeErrorMessage(
                  context,
                  state.message,
                  fallbackKey: 'authentication_failed',
                ),
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizeErrorMessage(
                  context,
                  state.message,
                  fallbackKey: 'authentication_failed',
                ),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        final theme = Theme.of(context);
        final l10n = AppLocalizations.of(context)!;
        return AppGradientScaffold(
          appBar: AppBar(leading: const BackButton()),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppPageIntroCard(
                          title: l10n.translate('create_account'),
                          trailing: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              AppIcons.userCircle,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        AppSurfaceCard(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.translate('join_as'),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _RoleCard(
                                      title: l10n.translate('buyer'),
                                      icon: AppIcons.buyer,
                                      isSelected: _selectedRole == 'buyer',
                                      onTap: () => setState(
                                        () => _selectedRole = 'buyer',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _RoleCard(
                                      title: l10n.translate('seller'),
                                      icon: AppIcons.seller,
                                      isSelected: _selectedRole == 'seller',
                                      onTap: () => setState(
                                        () => _selectedRole = 'seller',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: l10n.translate('full_name'),
                                  prefixIcon: const Icon(AppIcons.user),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return l10n.translate('enter_full_name');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: l10n.translate('email_address'),
                                  prefixIcon: const Icon(AppIcons.email),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return l10n.translate('enter_email');
                                  }
                                  if (!RegExp(
                                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                  ).hasMatch(value)) {
                                    return l10n.translate(
                                      'enter_valid_email_address',
                                    );
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: l10n.translate('password'),
                                  prefixIcon: const Icon(AppIcons.password),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return l10n.translate('enter_password');
                                  }
                                  if (value.length < 6) {
                                    return l10n.translate('password_min_6');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: l10n.translate('confirm_password'),
                                  prefixIcon: const Icon(AppIcons.password),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return l10n.translate(
                                      'confirm_password_prompt',
                                    );
                                  }
                                  if (value != _passwordController.text) {
                                    return l10n.translate(
                                      'passwords_do_not_match',
                                    );
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: state is AuthLoading
                                      ? null
                                      : () => _handleRegister(context),
                                  child: state is AuthLoading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.4,
                                          ),
                                        )
                                      : Text(l10n.translate('sign_up')),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.55),
            width: 1.6,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.grey.shade600,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.primary : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
