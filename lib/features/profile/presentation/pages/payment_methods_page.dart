import 'package:flutter/material.dart';
import 'package:untitled1/core/constants/supabase_constants.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/localization/localized_error_message.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_empty_state.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/features/profile/presentation/widgets/profile_page_shell.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  bool _isDeleting = false;

  Future<int> _loadLegacyMethodCount() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      return 0;
    }

    final rows = await SupabaseService.client
        .from(SupabaseTables.paymentMethods)
        .select('id')
        .eq('userId', uid);
    return rows.length;
  }

  Future<void> _deleteLegacyMethods() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null || _isDeleting) {
      return;
    }

    setState(() => _isDeleting = true);
    try {
      await SupabaseService.client
          .from(SupabaseTables.paymentMethods)
          .delete()
          .eq('userId', uid);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.translate('payment_methods_cleanup_success')),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .translate('payment_methods_cleanup_error')
                .replaceAll('{error}', localizeErrorMessage(context, error)),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseService.currentUserId;

    return ProfilePageShell(
      title: context.translate('payment_methods'),
      subtitle: context.translate('online_payments_disabled_body'),
      child: uid == null
          ? AppEmptyState(
              icon: AppIcons.payment,
              title: context.translate('sign_in_required'),
              subtitle: context.translate('sign_in_payment_methods'),
            )
          : FutureBuilder<int>(
              future: _loadLegacyMethodCount(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final legacyCount = snapshot.data ?? 0;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    AppSurfaceCard(
                      radius: 28,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  AppIcons.warning,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  context.translate(
                                    'online_payments_disabled_title',
                                  ),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.translate('online_payments_disabled_body'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            legacyCount == 0
                                ? context.translate('no_legacy_payment_methods')
                                : context
                                      .translate('legacy_payment_methods_found')
                                      .replaceAll('{count}', '$legacyCount'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (legacyCount > 0) ...[
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isDeleting
                                    ? null
                                    : _deleteLegacyMethods,
                                icon: _isDeleting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(AppIcons.warning),
                                label: Text(
                                  _isDeleting
                                      ? context.translate('deleting')
                                      : context.translate(
                                          'delete_legacy_payment_methods',
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
