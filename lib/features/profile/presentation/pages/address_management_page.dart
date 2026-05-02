import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:untitled1/core/constants/algeria_communes.dart';
import 'package:untitled1/core/constants/algeria_wilayas.dart';
import 'package:untitled1/core/constants/supabase_constants.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_empty_state.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/features/profile/presentation/widgets/profile_page_shell.dart';

class AddressManagementPage extends StatefulWidget {
  const AddressManagementPage({super.key});

  @override
  State<AddressManagementPage> createState() => _AddressManagementPageState();
}

class _AddressManagementPageState extends State<AddressManagementPage> {
  String _wilayaCode(String? label) {
    if (label == null || label.trim().isEmpty) {
      return '';
    }
    return label.split('-').first.trim().padLeft(2, '0');
  }

  List<String> _communesForWilaya(String? wilayaLabel) {
    return algeriaCommunesByWilayaCode[_wilayaCode(wilayaLabel)] ?? const [];
  }

  String? _normalizeWilayaLabel(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final normalized = value.trim().toLowerCase();
    for (final wilaya in algeriaWilayas) {
      final code = wilaya.split('-').first.trim();
      final name = wilaya.split('-').last.trim();
      if (normalized == wilaya.toLowerCase() ||
          normalized == name.toLowerCase() ||
          normalized == code.toLowerCase()) {
        return wilaya;
      }
    }
    return null;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  void _showAddressDialog({Map<String, dynamic>? address, String? docId}) {
    final titleController = TextEditingController(
      text: address?['title'] ?? '',
    );
    final addressController = TextEditingController(
      text: address?['address'] ?? '',
    );
    final phoneController = TextEditingController(
      text: address?['phone'] ?? '',
    );
    final postalCodeController = TextEditingController(
      text: address?['postalCode'] ?? '',
    );
    var selectedWilaya = _normalizeWilayaLabel(address?['wilaya'] as String?);
    var selectedCommune = (address?['commune'] as String?)?.trim();
    var availableCommunes = _communesForWilaya(selectedWilaya);
    if (selectedCommune != null &&
        selectedCommune.isNotEmpty &&
        !availableCommunes.contains(selectedCommune)) {
      selectedCommune = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    docId == null
                        ? context.translate('add_new_address')
                        : context.translate('edit_address'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.translate('address_form_subtitle'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: context.translate('address_title'),
                      prefixIcon: Icon(AppIcons.note),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: addressController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: context.translate('full_address'),
                      prefixIcon: Icon(AppIcons.address),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedWilaya,
                    decoration: InputDecoration(
                      labelText: context.translate('wilaya'),
                      prefixIcon: Icon(AppIcons.mapPin),
                    ),
                    items: algeriaWilayas
                        .map(
                          (wilaya) => DropdownMenuItem<String>(
                            value: wilaya,
                            child: Text(wilaya),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setModalState(() {
                        selectedWilaya = value;
                        availableCommunes = _communesForWilaya(value);
                        if (!availableCommunes.contains(selectedCommune)) {
                          selectedCommune = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCommune,
                    decoration: InputDecoration(
                      labelText: context.translate('commune'),
                      prefixIcon: Icon(AppIcons.map),
                    ),
                    items: availableCommunes
                        .map(
                          (commune) => DropdownMenuItem<String>(
                            value: commune,
                            child: Text(
                              commune,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: availableCommunes.isEmpty
                        ? null
                        : (value) {
                            setModalState(() {
                              selectedCommune = value;
                            });
                          },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: postalCodeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    decoration: InputDecoration(
                      labelText: context.translate('postal_code'),
                      prefixIcon: Icon(AppIcons.info),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: context.translate('phone_number'),
                      prefixIcon: Icon(AppIcons.phone),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final uid = SupabaseService.currentUserId;
                        if (uid == null) {
                          _showMessage(
                            context.translate('sign_in_addresses'),
                            isError: true,
                          );
                          return;
                        }

                        if (titleController.text.trim().isEmpty ||
                            selectedCommune == null ||
                            selectedCommune!.trim().isEmpty ||
                            addressController.text.trim().isEmpty ||
                            phoneController.text.trim().isEmpty ||
                            selectedWilaya == null ||
                            postalCodeController.text.trim().length != 5) {
                          _showMessage(
                            context.translate('address_validation_error'),
                            isError: true,
                          );
                          return;
                        }

                        final data = {
                          'userId': uid,
                          'title': titleController.text.trim(),
                          'commune': selectedCommune!.trim(),
                          'address': addressController.text.trim(),
                          'wilaya': selectedWilaya,
                          'postalCode': postalCodeController.text.trim(),
                          'phone': phoneController.text.trim(),
                          'isDefault': address?['isDefault'] ?? false,
                          'updatedAt': DateTime.now().toUtc().toIso8601String(),
                        };

                        try {
                          if (docId == null) {
                            await SupabaseService.client
                                .from(SupabaseTables.addresses)
                                .insert(data);
                          } else {
                            await SupabaseService.client
                                .from(SupabaseTables.addresses)
                                .update(data)
                                .eq('id', docId)
                                .eq('userId', uid);
                          }

                          if (!context.mounted) return;
                          Navigator.pop(context);
                          _showMessage(
                            docId == null
                                ? context.translate('address_added')
                                : context.translate('address_updated'),
                          );
                        } catch (_) {
                          _showMessage(
                            context.translate('address_save_failed'),
                            isError: true,
                          );
                        }
                      },
                      child: Text(context.translate('save_address')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setAsDefault(String docId) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      _showMessage(context.translate('sign_in_addresses'), isError: true);
      return;
    }

    try {
      await SupabaseService.client.rpc(
        'set_default_address',
        params: {'p_user_id': uid, 'p_address_id': docId},
      );
      if (!mounted) return;
      _showMessage(context.translate('default_address_updated'));
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        context.translate('default_address_update_failed'),
        isError: true,
      );
    }
  }

  Future<void> _deleteAddress(String docId) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      _showMessage(context.translate('sign_in_addresses'), isError: true);
      return;
    }

    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.translate('delete_address')),
            content: Text(context.translate('delete_address_confirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.translate('cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                child: Text(context.translate('delete')),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;

    try {
      await SupabaseService.client
          .from(SupabaseTables.addresses)
          .delete()
          .eq('id', docId)
          .eq('userId', uid);
      if (!mounted) return;
      _showMessage(context.translate('address_deleted'));
    } catch (_) {
      if (!mounted) return;
      _showMessage(context.translate('address_delete_failed'), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseService.currentUserId;

    return ProfilePageShell(
      title: context.translate('shipping_addresses'),
      subtitle: context.translate('address_form_subtitle'),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton.icon(
            onPressed: () => _showAddressDialog(),
            icon: const Icon(AppIcons.plus),
            label: Text(context.translate('add_new_address')),
          ),
        ),
      ),
      child: uid == null
          ? AppEmptyState(
              icon: AppIcons.mapPin,
              title: context.translate('sign_in_required'),
              subtitle: context.translate('sign_in_addresses'),
            )
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseService.client
                  .from(SupabaseTables.addresses)
                  .stream(primaryKey: ['id'])
                  .eq('userId', uid)
                  .order('isDefault', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return AppEmptyState(
                    icon: AppIcons.warning,
                    title: context.translate('addresses_unavailable'),
                    subtitle: context.translate('addresses_load_error'),
                    accentColor: Colors.redAccent,
                  );
                }

                final docs = snapshot.data ?? const [];

                if (docs.isEmpty) {
                  return AppEmptyState(
                    icon: AppIcons.mapPin,
                    title: context.translate('no_addresses_saved'),
                    subtitle: context.translate('add_address_checkout'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final data = docs[index];
                    return _buildAddressCard(data, data['id'].toString());
                  },
                );
              },
            ),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> data, String docId) {
    final isDefault = data['isDefault'] ?? false;
    final theme = Theme.of(context);

    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      radius: 24,
      borderColor: isDefault
          ? AppColors.primary
          : theme.colorScheme.outline.withValues(alpha: 0.18),
      borderWidth: isDefault ? 1.6 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        data['title'],
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          context.translate('default_label'),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(AppIcons.more),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showAddressDialog(address: data, docId: docId);
                  } else if (value == 'delete') {
                    _deleteAddress(docId);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Text(context.translate('edit_address')),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text(
                      context.translate('delete_address'),
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data['address'],
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if ((data['commune'] as String?)?.isNotEmpty ?? false)
                _AddressMetaChip(label: data['commune'] as String),
              if ((data['wilaya'] as String?)?.isNotEmpty ?? false)
                _AddressMetaChip(label: data['wilaya'] as String),
              if ((data['postalCode'] as String?)?.isNotEmpty ?? false)
                _AddressMetaChip(label: 'CP ${data['postalCode']}'),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                AppIcons.phone,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data['phone'] ?? '+212 000-000000',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (!isDefault)
                TextButton(
                  onPressed: () => _setAsDefault(docId),
                  child: Text(context.translate('set_as_default')),
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }
}

class _AddressMetaChip extends StatelessWidget {
  const _AddressMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
