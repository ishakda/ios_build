import 'dart:io';
import 'package:flutter/material.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:untitled1/core/constants/supabase_constants.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/localization/localized_error_message.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_event.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_state.dart';
import 'package:untitled1/features/auth/presentation/cubit/profile_update_cubit.dart';
import 'package:untitled1/features/auth/presentation/cubit/profile_update_state.dart';
import 'package:untitled1/injection_container.dart';

class StoreSetupPage extends StatefulWidget {
  const StoreSetupPage({super.key});

  @override
  State<StoreSetupPage> createState() => _StoreSetupPageState();
}

class _StoreSetupPageState extends State<StoreSetupPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _storeNameController;
  late TextEditingController _storeDescriptionController;
  File? _logoFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user : null;
    _storeNameController = TextEditingController(
      text: user?.storeName ?? (user == null ? '' : '${user.name}\'s Store'),
    );
    _storeDescriptionController = TextEditingController(
      text: user?.storeDescription ?? '',
    );
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      setState(() {
        _logoFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadLogo(String userId) async {
    if (_logoFile == null) return null;

    setState(() => _isUploading = true);
    try {
      return await SupabaseService.uploadPublicFile(
        bucket: SupabaseBuckets.storeMedia,
        path: 'stores/$userId/logo.jpg',
        file: _logoFile!,
        contentType: 'image/jpeg',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context
                  .translate('upload_logo_failed')
                  .replaceAll('{error}', localizeErrorMessage(context, e)),
            ),
          ),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! Authenticated) {
      return AppGradientScaffold(
        appBar: AppBar(title: Text(context.translate('store_setup'))),
        body: Center(child: Text(context.translate('sign_in_store_setup'))),
      );
    }
    final user = authState.user;

    return BlocProvider(
      create: (_) => sl<ProfileUpdateCubit>(),
      child: BlocConsumer<ProfileUpdateCubit, ProfileUpdateState>(
        listener: (context, state) {
          if (state is ProfileUpdateFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  localizeErrorMessage(
                    context,
                    state.message,
                    fallbackKey: 'profile_update_failed_generic',
                  ),
                ),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is ProfileUpdateSuccess) {
            context.read<AuthBloc>().add(SessionUserUpdated(state.user));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.translate('store_setup_success')),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop();
          }
        },
        builder: (context, state) {
          final isSubmitting = _isUploading || state is ProfileUpdateSubmitting;

          return AppGradientScaffold(
            appBar: AppBar(
              title: Text(context.translate('store_setup')),
              automaticallyImplyLeading: false,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Text(
                      context.translate('store_setup_intro'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: AppColors.greyLight,
                          backgroundImage: _logoFile != null
                              ? FileImage(_logoFile!)
                              : const NetworkImage(
                                      'https://ui-avatars.com/api/?background=6C63FF&color=fff&size=200&name=Store',
                                    )
                                    as ImageProvider,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            backgroundColor: AppColors.primary,
                            radius: 18,
                            child: IconButton(
                              icon: const Icon(
                                AppIcons.camera,
                                size: 18,
                                color: Colors.white,
                              ),
                              onPressed: _pickLogo,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.translate('store_logo'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _storeNameController,
                      decoration: InputDecoration(
                        labelText: context.translate('store_name'),
                        prefixIcon: const Icon(AppIcons.store),
                        hintText: context.translate('store_name_hint'),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? context.translate('enter_store_name')
                          : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _storeDescriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: context.translate('store_description_label'),
                        prefixIcon: const Icon(AppIcons.note),
                        alignLabelWithHint: true,
                        hintText: context.translate('store_description_hint'),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (_formKey.currentState!.validate()) {
                                  final logoUrl = await _uploadLogo(user.id);
                                  if (!mounted) return;

                                  final updatedUser = user.copyWith(
                                    storeName: _storeNameController.text.trim(),
                                    storeDescription:
                                        _storeDescriptionController.text.trim(),
                                    storeLogo: logoUrl ?? user.storeLogo,
                                  );

                                  if (context.mounted) {
                                    context
                                        .read<ProfileUpdateCubit>()
                                        .updateUser(updatedUser);
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(context.translate('finish_setup')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
