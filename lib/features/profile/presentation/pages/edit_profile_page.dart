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
import 'package:untitled1/core/widgets/app_section_label.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_event.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_state.dart';
import 'package:untitled1/features/auth/presentation/cubit/profile_update_cubit.dart';
import 'package:untitled1/features/auth/presentation/cubit/profile_update_state.dart';
import 'package:untitled1/injection_container.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  TextEditingController? _storeNameController;
  TextEditingController? _storeDescriptionController;

  String? _profileImageUrl;
  File? _profileImageFile;

  String? _storeLogoUrl;
  File? _storeLogoFile;

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user : null;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _profileImageUrl = user?.profileImageUrl;

    if (user?.role == 'seller') {
      _storeNameController = TextEditingController(text: user?.storeName ?? '');
      _storeDescriptionController = TextEditingController(
        text: user?.storeDescription ?? '',
      );
      _storeLogoUrl = user?.storeLogo;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _storeNameController?.dispose();
    _storeDescriptionController?.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool forStoreLogo}) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      setState(() {
        if (forStoreLogo) {
          _storeLogoFile = File(pickedFile.path);
        } else {
          _profileImageFile = File(pickedFile.path);
        }
      });
    }
  }

  Future<String?> _uploadImage(
    String userId, {
    required bool forStoreLogo,
  }) async {
    final file = forStoreLogo ? _storeLogoFile : _profileImageFile;
    final currentUrl = forStoreLogo ? _storeLogoUrl : _profileImageUrl;

    if (file == null) return currentUrl;

    try {
      final fileName = forStoreLogo ? 'logo.jpg' : 'profile.jpg';
      return await SupabaseService.uploadPublicFile(
        bucket: forStoreLogo
            ? SupabaseBuckets.storeMedia
            : SupabaseBuckets.userProfiles,
        path: forStoreLogo
            ? 'stores/$userId/$fileName'
            : 'profiles/$userId/$fileName',
        file: file,
        contentType: 'image/jpeg',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context
                  .translate(
                    forStoreLogo
                        ? 'store_logo_upload_failed'
                        : 'image_upload_failed',
                  )
                  .replaceAll('{error}', localizeErrorMessage(context, e)),
            ),
          ),
        );
      }
      return currentUrl;
    }
  }

  void _showEditFieldDialog({
    required String title,
    required TextEditingController controller,
    bool isMultiline = false,
    String? Function(String?)? validator,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                autofocus: true,
                maxLines: isMultiline ? 4 : 1,
                decoration: InputDecoration(
                  hintText: context
                      .translate('enter_field')
                      .replaceAll('{field}', title),
                  filled: true,
                  fillColor: AppColors.primary.withValues(alpha: 0.05),
                ),
                validator: validator,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Refresh the main page with new value
                    Navigator.pop(context);
                  },
                  child: Text(context.translate('confirm')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! Authenticated) {
      return AppGradientScaffold(
        appBar: AppBar(title: Text(context.translate('profile_settings'))),
        body: Center(child: Text(context.translate('sign_in_edit_profile'))),
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
                content: Text(context.translate('profile_updated_success')),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        },
        builder: (context, state) {
          final isSubmitting = _isUploading || state is ProfileUpdateSubmitting;

          return AppGradientScaffold(
            appBar: AppBar(
              title: Text(context.translate('profile_settings')),
              centerTitle: true,
              leading: const BackButton(),
              elevation: 0,
            ),
            body: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  _buildProfileAvatarSection(),
                  const SizedBox(height: 32),

                  AppSectionLabel(
                    text: context
                        .translate('personal_information')
                        .toUpperCase(),
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                  ),
                  AppSurfaceCard(
                    radius: 24,
                    child: Column(
                      children: [
                        _EditableTile(
                          icon: AppIcons.user,
                          title: context.translate('full_name'),
                          value: _nameController.text,
                          onTap: () => _showEditFieldDialog(
                            title: context.translate('full_name'),
                            controller: _nameController,
                            validator: (v) => v!.isEmpty
                                ? context.translate('name_empty')
                                : null,
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        _EditableTile(
                          icon: AppIcons.phone,
                          title: context.translate('phone_number'),
                          value: _phoneController.text.isEmpty
                              ? context.translate('not_set')
                              : _phoneController.text,
                          onTap: () => _showEditFieldDialog(
                            title: context.translate('phone_number'),
                            controller: _phoneController,
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        _EditableTile(
                          icon: AppIcons.email,
                          title: context.translate('email'),
                          value: user.email,
                          isEditable: false,
                        ),
                      ],
                    ),
                  ),

                  if (user.role == 'seller') ...[
                    const SizedBox(height: 32),
                    AppSectionLabel(
                      text: context
                          .translate('store_information')
                          .toUpperCase(),
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                    ),
                    _buildStoreLogoSection(),
                    const SizedBox(height: 12),
                    AppSurfaceCard(
                      radius: 24,
                      child: Column(
                        children: [
                          _EditableTile(
                            icon: AppIcons.store,
                            title: context.translate('store_name'),
                            value: _storeNameController!.text,
                            onTap: () => _showEditFieldDialog(
                              title: context.translate('store_name'),
                              controller: _storeNameController!,
                              validator: (v) => v!.isEmpty
                                  ? context.translate('store_name_empty')
                                  : null,
                            ),
                          ),
                          const Divider(height: 1, indent: 56),
                          _EditableTile(
                            icon: AppIcons.note,
                            title: context.translate('store_description_label'),
                            value: _storeDescriptionController!.text.isEmpty
                                ? context.translate('no_description')
                                : _storeDescriptionController!.text,
                            onTap: () => _showEditFieldDialog(
                              title: context.translate(
                                'store_description_label',
                              ),
                              controller: _storeDescriptionController!,
                              isMultiline: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setState(() => _isUploading = true);
                              final newProfileUrl = await _uploadImage(
                                user.id,
                                forStoreLogo: false,
                              );
                              final newStoreLogoUrl = user.role == 'seller'
                                  ? await _uploadImage(
                                      user.id,
                                      forStoreLogo: true,
                                    )
                                  : null;
                              setState(() => _isUploading = false);

                              if (!context.mounted) return;

                              final updatedUser = user.copyWith(
                                name: _nameController.text.trim(),
                                phoneNumber: _phoneController.text.trim(),
                                profileImageUrl: newProfileUrl,
                                storeName: user.role == 'seller'
                                    ? _storeNameController!.text.trim()
                                    : null,
                                storeDescription: user.role == 'seller'
                                    ? _storeDescriptionController!.text.trim()
                                    : null,
                                storeLogo: newStoreLogoUrl,
                              );

                              context.read<ProfileUpdateCubit>().updateUser(
                                updatedUser,
                              );
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Text(context.translate('save_changes')),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileAvatarSection() {
    return Center(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.1),
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: AppColors.greyLight,
              backgroundImage: _profileImageFile != null
                  ? FileImage(_profileImageFile!)
                  : (_profileImageUrl != null
                            ? NetworkImage(_profileImageUrl!)
                            : const NetworkImage(
                                'https://ui-avatars.com/api/?background=6C63FF&color=fff&size=200&name=Sahla',
                              ))
                        as ImageProvider,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _pickImage(forStoreLogo: false),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  AppIcons.camera,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreLogoSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.greyLight,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    width: 3,
                  ),
                  image: DecorationImage(
                    image: _storeLogoFile != null
                        ? FileImage(_storeLogoFile!)
                        : (_storeLogoUrl != null
                                  ? NetworkImage(_storeLogoUrl!)
                                  : const NetworkImage(
                                      'https://ui-avatars.com/api/?background=eee&color=666&size=200&name=Store',
                                    ))
                              as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: -4,
                right: -4,
                child: GestureDetector(
                  onTap: () => _pickImage(forStoreLogo: true),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      AppIcons.camera,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.translate('store_logo'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _EditableTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;
  final bool isEditable;

  const _EditableTile({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
    this.isEditable = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: isEditable ? onTap : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        value,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isEditable
          ? const Icon(AppIcons.edit, size: 18, color: AppColors.primary)
          : null,
    );
  }
}
