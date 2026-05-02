import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/features/admin/domain/entities/admin_product_report.dart';
import 'package:untitled1/features/admin/domain/entities/admin_refund_request.dart';
import 'package:untitled1/features/admin/domain/entities/admin_support_ticket.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';
import 'package:untitled1/features/checkout/domain/entities/order.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';

class MetricData {
  const MetricData(this.title, this.value, this.color);

  final String title;
  final String value;
  final Color color;
}

class TopMetrics extends StatelessWidget {
  const TopMetrics({super.key, required this.cards});

  final List<MetricData> cards;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: cards
          .map(
            (card) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: card == cards.last ? 0 : 10),
                child: AppSurfaceCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        card.value,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: card.color,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Color adminStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'resolved':
    case 'approved':
    case 'refunded':
    case 'closed':
      return AppColors.success;
    case 'reviewing':
    case 'in_progress':
      return AppColors.primary;
    case 'dismissed':
    case 'rejected':
      return Colors.redAccent;
    default:
      return AppColors.accent;
  }
}

String adminStatusLabel(AppLocalizations l10n, String status) {
  switch (status.toLowerCase()) {
    case 'open':
      return l10n.translate('status_open');
    case 'in_progress':
      return l10n.translate('status_in_progress');
    case 'reviewing':
      return l10n.translate('status_reviewing');
    case 'resolved':
      return l10n.translate('status_resolved');
    case 'closed':
      return l10n.translate('status_closed');
    case 'dismissed':
      return l10n.translate('status_dismissed');
    case 'rejected':
      return l10n.translate('status_rejected');
    case 'refunded':
      return l10n.translate('status_refunded');
    case 'approved':
      return l10n.translate('status_approved');
    case 'pending':
      return l10n.translate('pending');
    default:
      return status;
  }
}

class CardHeader extends StatelessWidget {
  const CardHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    required this.avatarText,
    required this.isBusy,
  });

  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final String avatarText;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: badgeColor.withValues(alpha: 0.12),
          child: Text(
            avatarText,
            style: TextStyle(color: badgeColor, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            StatusChip(label: badgeText, color: badgeColor),
            if (isBusy) ...[
              const SizedBox(height: 8),
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class UserAdminCard extends StatelessWidget {
  const UserAdminCard({
    super.key,
    required this.user,
    required this.isCurrentAdmin,
    required this.isBusy,
    required this.onApprove,
    required this.onRevokeApproval,
    required this.onBan,
    required this.onUnban,
    required this.onToggleCod,
  });

  final User user;
  final bool isCurrentAdmin;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onRevokeApproval;
  final VoidCallback onBan;
  final VoidCallback onUnban;
  final VoidCallback onToggleCod;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final disableModeration = isCurrentAdmin || user.isAdmin;

    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            title: user.name,
            subtitle: user.email,
            badgeText: user.role.toUpperCase(),
            badgeColor: AppColors.primary,
            avatarText: user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
            isBusy: isBusy,
          ),
          if (user.storeName?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              user.storeName!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (user.isSeller && !user.isSellerApproved && !user.isBanned)
                StatusChip(
                  label: l10n.translate('status_pending_approval'),
                  color: AppColors.accent,
                ),
              if (user.isSellerApproved)
                StatusChip(
                  label: l10n.translate('status_approved'),
                  color: AppColors.success,
                ),
              if (user.isVerifiedSeller)
                StatusChip(
                  label: l10n.translate('status_verified'),
                  color: AppColors.primary,
                ),
              if (user.isCodBlocked)
                StatusChip(
                  label: l10n.translate('status_cod_blocked'),
                  color: Colors.deepOrange,
                ),
              if (user.isBanned)
                StatusChip(
                  label: l10n.translate('status_suspended'),
                  color: Colors.redAccent,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            user.phoneNumber?.trim().isNotEmpty == true
                ? '${l10n.translate('phone_label')}: ${user.phoneNumber}'
                : l10n.translate('phone_missing'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (user.banReason?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              '${l10n.translate('ban_reason')}: ${user.banReason}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.redAccent),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (user.isSeller && !user.isBanned)
                OutlinedButton(
                  onPressed: disableModeration || isBusy
                      ? null
                      : user.isSellerApproved
                      ? onRevokeApproval
                      : onApprove,
                  child: Text(
                    user.isSellerApproved
                        ? l10n.translate('revoke_approval')
                        : l10n.translate('approve_seller'),
                  ),
                ),
              OutlinedButton(
                onPressed: disableModeration || isBusy ? null : onToggleCod,
                child: Text(
                  user.isCodBlocked
                      ? l10n.translate('unblock_cod')
                      : l10n.translate('block_cod'),
                ),
              ),
              FilledButton(
                onPressed: disableModeration || isBusy
                    ? null
                    : user.isBanned
                    ? onUnban
                    : onBan,
                style: FilledButton.styleFrom(
                  backgroundColor: user.isBanned
                      ? AppColors.success
                      : Colors.redAccent,
                ),
                child: Text(
                  user.isBanned
                      ? l10n.translate('unsuspend')
                      : l10n.translate('suspend'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TicketAdminCard extends StatelessWidget {
  const TicketAdminCard({
    super.key,
    required this.ticket,
    required this.user,
    required this.isBusy,
    required this.onUpdate,
  });

  final AdminSupportTicket ticket;
  final User? user;
  final bool isBusy;
  final ValueChanged<String> onUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            title: ticket.subject,
            subtitle: user == null
                ? ticket.userId
                : '${user!.name} • ${user!.email}',
            badgeText: adminStatusLabel(l10n, ticket.status).toUpperCase(),
            badgeColor: adminStatusColor(ticket.status),
            avatarText: user?.name.isNotEmpty == true
                ? user!.name[0].toUpperCase()
                : '?',
            isBusy: isBusy,
          ),
          const SizedBox(height: 12),
          Text(ticket.message),
          if (ticket.adminNote?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              '${l10n.translate('admin_note')}: ${ticket.adminNote}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            DateFormat('dd MMM yyyy, HH:mm').format(ticket.createdAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const ['open', 'in_progress', 'resolved', 'closed']
                .map(
                  (status) => OutlinedButton(
                    onPressed: isBusy ? null : () => onUpdate(status),
                    child: Text(adminStatusLabel(l10n, status)),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class ReportAdminCard extends StatelessWidget {
  const ReportAdminCard({
    super.key,
    required this.report,
    required this.product,
    required this.reporter,
    required this.seller,
    required this.isBusy,
    required this.onUpdate,
    this.onDeleteProduct,
  });

  final AdminProductReport report;
  final Product? product;
  final User? reporter;
  final User? seller;
  final bool isBusy;
  final ValueChanged<String> onUpdate;
  final VoidCallback? onDeleteProduct;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            title: product?.name ?? l10n.translate('deleted_product'),
            subtitle:
                '${l10n.translate('reporter_label')}: ${reporter?.name ?? report.reporterUserId}${seller != null ? ' • ${l10n.translate('seller_label')}: ${seller!.name}' : ''}',
            badgeText: adminStatusLabel(l10n, report.status).toUpperCase(),
            badgeColor: adminStatusColor(report.status),
            avatarText: product?.name.isNotEmpty == true
                ? product!.name[0].toUpperCase()
                : '!',
            isBusy: isBusy,
          ),
          const SizedBox(height: 12),
          Text(
            '${l10n.translate('reason')}: ${report.reason}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (report.details?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(report.details!),
          ],
          if (report.adminNote?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              '${l10n.translate('admin_note')}: ${report.adminNote}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            DateFormat('dd MMM yyyy, HH:mm').format(report.createdAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...const ['open', 'reviewing', 'resolved', 'dismissed'].map(
                (status) => OutlinedButton(
                  onPressed: isBusy ? null : () => onUpdate(status),
                  child: Text(adminStatusLabel(l10n, status)),
                ),
              ),
              FilledButton(
                onPressed: isBusy ? null : onDeleteProduct,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: Text(l10n.translate('delete_product')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RefundAdminCard extends StatelessWidget {
  const RefundAdminCard({
    super.key,
    required this.request,
    required this.user,
    required this.order,
    required this.isBusy,
    required this.onUpdate,
  });

  final AdminRefundRequest request;
  final User? user;
  final Order? order;
  final bool isBusy;
  final ValueChanged<String> onUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            title:
                '${l10n.translate('order_number_short')} ${order?.displayNumber ?? request.orderId.toUpperCase()}',
            subtitle: user == null
                ? request.buyerId
                : '${user!.name} • ${user!.email}',
            badgeText: adminStatusLabel(l10n, request.status).toUpperCase(),
            badgeColor: adminStatusColor(request.status),
            avatarText: user?.name.isNotEmpty == true
                ? user!.name[0].toUpperCase()
                : '\$',
            isBusy: isBusy,
          ),
          const SizedBox(height: 12),
          Text(
            '${l10n.translate('reason')}: ${request.reason}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (request.details?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(request.details!),
          ],
          if (order != null) ...[
            const SizedBox(height: 8),
            Text(
              '${l10n.translate('order_total')}: ${order!.totalAmount.toStringAsFixed(0)} DZD',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (request.adminNote?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              '${l10n.translate('admin_note')}: ${request.adminNote}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            DateFormat('dd MMM yyyy, HH:mm').format(request.createdAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const ['pending', 'approved', 'rejected', 'refunded']
                .map(
                  (status) => OutlinedButton(
                    onPressed: isBusy ? null : () => onUpdate(status),
                    child: Text(adminStatusLabel(l10n, status)),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
