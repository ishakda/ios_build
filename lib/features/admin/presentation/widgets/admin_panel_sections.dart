import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_empty_state.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:untitled1/features/admin/presentation/cubit/admin_users_state.dart';
import 'package:untitled1/features/admin/presentation/widgets/admin_panel_cards.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';

typedef AdminNoteRequester =
    Future<String?> Function({required String title, required String hint});

void handleAdminPanelFeedback(BuildContext context, AdminUsersState state) {
  final messenger = ScaffoldMessenger.of(context);
  if (state.errorMessage != null) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(state.errorMessage!),
        backgroundColor: Colors.redAccent,
      ),
    );
  } else if (state.actionMessage != null) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(state.actionMessage!),
        backgroundColor: AppColors.success,
      ),
    );
  }
}

class AdminOverviewSection extends StatelessWidget {
  const AdminOverviewSection({super.key, required this.state});

  final AdminUsersState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        TopMetrics(
          cards: [
            MetricData(l10n.translate('users'), '${state.totalUserCount}', AppColors.primary),
            MetricData(
              l10n.translate('open_cases'),
              '${state.openCaseCount}',
              AppColors.accent,
            ),
            MetricData(
              l10n.translate('approved_sellers'),
              '${state.approvedSellerCount}',
              AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 12),
        TopMetrics(
          cards: [
            MetricData(
              l10n.translate('cancelled_orders'),
              '${state.cancelledOrderCount}',
              Colors.redAccent,
            ),
            MetricData(
              l10n.translate('delivered_orders'),
              '${state.deliveredOrderCount}',
              AppColors.primary,
            ),
            MetricData(
              l10n.translate('cod_blocked'),
              '${state.codBlockedCount}',
              Colors.deepOrange,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _InsightCard(
          title: l10n.translate('risk_signals'),
          subtitle: l10n.translate('risk_signals_subtitle'),
          children: [
            _TopList(
              title: l10n.translate('buyers_most_cancelled_orders'),
              entries: state.cancelledOrdersByBuyer.take(5).toList(),
              resolveLabel: (entry) =>
                  state.userById(entry.key)?.name ?? entry.key,
              emptyText: l10n.translate('no_buyer_cancellation_spikes'),
            ),
            const SizedBox(height: 16),
            _TopList(
              title: l10n.translate('sellers_most_cancelled_orders'),
              entries: state.cancelledOrdersBySeller.take(5).toList(),
              resolveLabel: (entry) =>
                  state.userById(entry.key)?.storeName ??
                  state.userById(entry.key)?.name ??
                  entry.key,
              emptyText: l10n.translate('no_seller_cancellation_spikes'),
            ),
            const SizedBox(height: 16),
            _TopList(
              title: l10n.translate('most_reported_products'),
              entries: state.reportsByProduct.take(5).toList(),
              resolveLabel: (entry) =>
                  state.productById(entry.key)?.name ?? entry.key,
              emptyText: l10n.translate('no_product_reporting_spikes'),
            ),
          ],
        ),
      ],
    );
  }
}

class AdminUsersSection extends StatelessWidget {
  const AdminUsersSection({
    super.key,
    required this.state,
    required this.currentUser,
    required this.searchController,
    required this.requestNote,
  });

  final AdminUsersState state;
  final User currentUser;
  final TextEditingController searchController;
  final AdminNoteRequester requestNote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visibleUsers = state.visibleUsers;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        TopMetrics(
          cards: [
            MetricData(
              l10n.translate('pending_sellers'),
              '${state.pendingSellerCount}',
              AppColors.accent,
            ),
            MetricData(l10n.translate('sellers'), '${state.sellerCount}', AppColors.primary),
            MetricData(l10n.translate('suspended'), '${state.bannedCount}', Colors.redAccent),
          ],
        ),
        const SizedBox(height: 16),
        AppSurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: searchController,
                onChanged: context.read<AdminUsersCubit>().setQuery,
                decoration: InputDecoration(
                  hintText: l10n.translate('search_admin_users_hint'),
                  prefixIcon: const Icon(AppIcons.search),
                  suffixIcon: state.query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            searchController.clear();
                            context.read<AdminUsersCubit>().setQuery('');
                          },
                          icon: const Icon(AppIcons.close),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AdminUserFilter.values
                    .map(
                      (filter) => ChoiceChip(
                        label: Text(l10n.translate(_filterLabel(filter))),
                        selected: state.filter == filter,
                        onSelected: (_) =>
                            context.read<AdminUsersCubit>().setFilter(filter),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (state.isLoading && state.users.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (visibleUsers.isEmpty)
          AppEmptyState(
            icon: AppIcons.search,
            title: l10n.translate('no_users_found'),
            subtitle: l10n.translate('try_another_filter'),
          )
        else
          ...visibleUsers.map(
            (user) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: UserAdminCard(
                user: user,
                isCurrentAdmin: user.id == currentUser.id,
                isBusy: state.actionUserId == user.id,
                onApprove: () =>
                    context.read<AdminUsersCubit>().approveSeller(user),
                onRevokeApproval: () =>
                    context.read<AdminUsersCubit>().revokeSellerApproval(user),
                onBan: () async {
                  final reason = await requestNote(
                    title: l10n.translate('suspend_user'),
                    hint: l10n.translate('suspend_reason_hint'),
                  );
                  if (!context.mounted) return;
                  await context.read<AdminUsersCubit>().banUser(
                    user,
                    reason: reason,
                  );
                },
                onUnban: () => context.read<AdminUsersCubit>().unbanUser(user),
                onToggleCod: () => context.read<AdminUsersCubit>().setCodBlock(
                  user,
                  !user.isCodBlocked,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AdminTicketsSection extends StatelessWidget {
  const AdminTicketsSection({
    super.key,
    required this.state,
    required this.requestNote,
  });

  final AdminUsersState state;
  final AdminNoteRequester requestNote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tickets = state.sortedTickets;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        TopMetrics(
          cards: [
            MetricData(
              l10n.translate('open_tickets'),
              '${state.openTicketCount}',
              AppColors.primary,
            ),
            MetricData(
              l10n.translate('total'),
              '${state.supportTickets.length}',
              AppColors.accent,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (state.isLoading && tickets.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (tickets.isEmpty)
          AppEmptyState(
            icon: AppIcons.support,
            title: l10n.translate('no_support_tickets'),
            subtitle: l10n.translate('support_tickets_will_appear'),
          )
        else
          ...tickets.map(
            (ticket) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TicketAdminCard(
                ticket: ticket,
                user: state.userById(ticket.userId),
                isBusy: state.actionUserId == ticket.id,
                onUpdate: (status) async {
                  final note = await requestNote(
                    title: l10n.translate('update_ticket'),
                    hint: l10n.translate('ticket_note_hint'),
                  );
                  if (!context.mounted) return;
                  await context.read<AdminUsersCubit>().updateTicket(
                    ticket,
                    status: status,
                    adminNote: note,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class AdminReportsSection extends StatelessWidget {
  const AdminReportsSection({
    super.key,
    required this.state,
    required this.requestNote,
  });

  final AdminUsersState state;
  final AdminNoteRequester requestNote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reports = state.sortedReports;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        TopMetrics(
          cards: [
            MetricData(
              l10n.translate('open_reports'),
              '${state.openReportCount}',
              Colors.deepOrange,
            ),
            MetricData(
              l10n.translate('products'),
              '${state.products.length}',
              AppColors.primary,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (state.isLoading && reports.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (reports.isEmpty)
          AppEmptyState(
            icon: AppIcons.warning,
            title: l10n.translate('no_product_reports'),
            subtitle: l10n.translate('product_reports_will_appear'),
          )
        else
          ...reports.map(
            (report) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ReportAdminCard(
                report: report,
                product: state.productById(report.productId),
                reporter: state.userById(report.reporterUserId),
                seller: report.sellerId == null
                    ? null
                    : state.userById(report.sellerId!),
                isBusy: state.actionUserId == report.id,
                onUpdate: (status) async {
                  final note = await requestNote(
                    title: l10n.translate('update_report'),
                    hint: l10n.translate('moderation_note_hint'),
                  );
                  if (!context.mounted) return;
                  await context.read<AdminUsersCubit>().updateReport(
                    report,
                    status: status,
                    adminNote: note,
                  );
                },
                onDeleteProduct: state.productById(report.productId) == null
                    ? null
                    : () async {
                        final product = state.productById(report.productId);
                        if (product == null) return;
                        await context.read<AdminUsersCubit>().deleteProduct(
                          product,
                        );
                      },
              ),
            ),
          ),
      ],
    );
  }
}

class AdminRefundsSection extends StatelessWidget {
  const AdminRefundsSection({
    super.key,
    required this.state,
    required this.requestNote,
  });

  final AdminUsersState state;
  final AdminNoteRequester requestNote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final requests = state.sortedRefundRequests;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        TopMetrics(
          cards: [
            MetricData(
              l10n.translate('pending_refunds'),
              '${state.pendingRefundCount}',
              AppColors.accent,
            ),
            MetricData(
              l10n.translate('orders'),
              '${state.orders.length}',
              AppColors.primary,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (state.isLoading && requests.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (requests.isEmpty)
          AppEmptyState(
            icon: AppIcons.receipt,
            title: l10n.translate('no_refund_requests'),
            subtitle: l10n.translate('refund_requests_will_appear'),
          )
        else
          ...requests.map(
            (request) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RefundAdminCard(
                request: request,
                user: state.userById(request.buyerId),
                order: state.orderById(request.orderId),
                isBusy: state.actionUserId == request.id,
                onUpdate: (status) async {
                  final note = await requestNote(
                    title: l10n.translate('update_refund_request'),
                    hint: l10n.translate('refund_note_hint'),
                  );
                  if (!context.mounted) return;
                  await context.read<AdminUsersCubit>().updateRefundRequest(
                    request,
                    status: status,
                    adminNote: note,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

String _filterLabel(AdminUserFilter filter) {
  return switch (filter) {
    AdminUserFilter.all => 'all',
    AdminUserFilter.pendingSellers => 'pending_sellers',
    AdminUserFilter.sellers => 'sellers',
    AdminUserFilter.buyers => 'buyers',
    AdminUserFilter.banned => 'suspended',
  };
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _TopList extends StatelessWidget {
  const _TopList({
    required this.title,
    required this.entries,
    required this.resolveLabel,
    required this.emptyText,
  });

  final String title;
  final List<MapEntry<String, int>> entries;
  final String Function(MapEntry<String, int> entry) resolveLabel;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          Text(
            emptyText,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          )
        else
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      resolveLabel(entry),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  StatusChip(label: '${entry.value}', color: AppColors.accent),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
