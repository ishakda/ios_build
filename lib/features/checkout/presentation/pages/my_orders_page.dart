import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/localization/localized_error_message.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_empty_state.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:untitled1/core/widgets/app_page_intro_card.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_state.dart';
import 'package:untitled1/features/checkout/domain/repositories/order_repository.dart';
import 'package:untitled1/features/checkout/domain/entities/order.dart';
import 'package:untitled1/features/checkout/presentation/bloc/order_bloc.dart';
import 'package:untitled1/features/checkout/presentation/bloc/order_event.dart';
import 'package:untitled1/features/checkout/presentation/bloc/order_state.dart';
import 'package:untitled1/features/product/presentation/pages/write_review_page.dart';
import 'package:untitled1/injection_container.dart';

import 'order_tracking_page.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key, this.initialStatus});

  final String? initialStatus;

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  bool _startedStreaming = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedStreaming) {
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _startedStreaming = true;
      context.read<OrderBloc>().add(StreamBuyerOrders(authState.user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 5,
      initialIndex: _getInitialIndex(),
      child: AppGradientScaffold(
        appBar: AppBar(
          title: Text(context.translate('my_orders')),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            labelColor: AppColors.primary,
            unselectedLabelColor: theme.textTheme.bodyMedium?.color,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            tabs: [
              Tab(text: context.translate('all')),
              Tab(text: context.translate('processing_filter')),
              Tab(text: context.translate('shipped_filter')),
              Tab(text: context.translate('to_review')),
              Tab(text: context.translate('cancelled_filter')),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AppPageIntroCard(
                title: context.translate('my_orders'),
                trailing: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(AppIcons.orders, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Expanded(
              child: TabBarView(
                children: [
                  _OrderList(statusFilter: null),
                  _OrderList(statusFilter: _OrderTabStatus.processing),
                  _OrderList(statusFilter: _OrderTabStatus.shipped),
                  _OrderList(statusFilter: _OrderTabStatus.toReview),
                  _OrderList(statusFilter: _OrderTabStatus.cancelled),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getInitialIndex() {
    final raw = widget.initialStatus?.trim();
    if (raw == null || raw.isEmpty) {
      return 0;
    }

    final normalized = raw.toLowerCase();
    if (normalized == 'to_pay' ||
        normalized == 'to pay' ||
        normalized == 'processing' ||
        normalized == context.translate('processing_filter').toLowerCase()) {
      return 1;
    }
    if (normalized == 'to_ship' ||
        normalized == 'to ship' ||
        normalized == 'shipped' ||
        normalized == context.translate('shipped_filter').toLowerCase()) {
      return 2;
    }
    if (normalized == 'to_review' ||
        normalized == 'to review' ||
        normalized == context.translate('to_review').toLowerCase()) {
      return 3;
    }
    if (normalized == 'cancelled' ||
        normalized == context.translate('cancelled_filter').toLowerCase()) {
      return 4;
    }
    return 0;
  }
}

enum _OrderTabStatus { processing, shipped, toReview, cancelled }

class _OrderList extends StatelessWidget {
  const _OrderList({this.statusFilter});

  final _OrderTabStatus? statusFilter;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrderBloc, OrderState>(
      builder: (context, state) {
        if (state is OrdersLoading || state is OrdersInitial) {
          return _buildSkeleton(context);
        }

        if (state is OrderError) {
          return AppEmptyState(
            icon: AppIcons.warning,
            title: context.translate('orders_unavailable'),
            subtitle: context.translate('orders_load_error'),
            accentColor: Colors.redAccent,
            actionLabel: context.translate('go_back'),
            onAction: () => Navigator.of(context).maybePop(),
          );
        }

        if (state is OrdersLoaded) {
          final orders = statusFilter == null
              ? state.orders
              : state.orders
                    .where((order) => _matchesStatus(order, statusFilter!))
                    .toList();

          if (orders.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              return _OrderCard(order: orders[index])
                  .animate()
                  .fadeIn(delay: (index * 90).ms)
                  .slideY(begin: 0.08, end: 0);
            },
          );
        }

        return _buildEmptyState(context);
      },
    );
  }

  bool _matchesStatus(Order order, _OrderTabStatus filter) {
    final normalized = order.status.toLowerCase();
    switch (filter) {
      case _OrderTabStatus.processing:
        return normalized == 'processing';
      case _OrderTabStatus.shipped:
        return normalized == 'shipped';
      case _OrderTabStatus.toReview:
        return normalized == 'delivered' || normalized == 'received';
      case _OrderTabStatus.cancelled:
        return normalized == 'cancelled';
    }
  }

  String _tabTitle(BuildContext context, _OrderTabStatus? filter) {
    switch (filter) {
      case _OrderTabStatus.processing:
        return context.translate('processing_filter');
      case _OrderTabStatus.shipped:
        return context.translate('shipped_filter');
      case _OrderTabStatus.toReview:
        return context.translate('to_review');
      case _OrderTabStatus.cancelled:
        return context.translate('cancelled_filter');
      case null:
        return context.translate('my_orders');
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return AppEmptyState(
      icon: AppIcons.bagOpen,
      title: statusFilter == null
          ? context.translate('no_orders_yet')
          : context
                .translate('no_status_orders')
                .replaceAll('{status}', _tabTitle(context, statusFilter)),
      subtitle: context.translate('order_history_desc'),
      actionLabel: context.translate('shop_now'),
      onAction: () => Navigator.of(context).popUntil((route) => route.isFirst),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) =>
          Container(
                height: 158,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.12),
                  ),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(
                duration: 1500.ms,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < 360;
    final canCancel = _canCancel(order.status);
    final canConfirmReceive = order.status.toLowerCase() == 'shipped';
    final canReview =
        order.status.toLowerCase() == 'delivered' ||
        order.status.toLowerCase() == 'received';
    final canRequestRefund =
        order.status.toLowerCase() == 'delivered' ||
        order.status.toLowerCase() == 'received' ||
        order.status.toLowerCase() == 'cancelled';
    final canRetryPayment = _canRetryPayment(order);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderTrackingPage(order: order),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: AppSurfaceCard(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        radius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.translate('order_id')}: #${order.displayNumber}',
                        style: theme.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat(
                          'MMM dd, yyyy - hh:mm a',
                        ).format(order.orderDate),
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _StatusBadge(status: order.status),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                SizedBox(
                  height: 40,
                  width: isCompact ? 144 : 184,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    itemCount: order.items.length > 3 ? 4 : order.items.length,
                    itemBuilder: (context, i) {
                      if (i == 3 && order.items.length > 3) {
                        return Container(
                          width: 40,
                          margin: const EdgeInsetsDirectional.only(end: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.18,
                              ),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '+${order.items.length - 3}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      }
                      return Container(
                        width: 40,
                        margin: const EdgeInsetsDirectional.only(end: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: NetworkImage(
                              order.items[i].product.imageUrl,
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: isCompact ? 0 : 132,
                    maxWidth: isCompact ? double.infinity : 180,
                  ),
                  child: Column(
                    crossAxisAlignment: isCompact
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end,
                    children: [
                      Text(
                        context
                            .translate('items_count')
                            .replaceAll('{count}', '${order.items.length}'),
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${order.totalAmount.toStringAsFixed(0)} ${context.translate('dzd')}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FutureBuilder<_ShipmentSummary?>(
              future: _loadShipmentSummary(order.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 48,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                return _ShipmentSummaryCard(
                  summary: snapshot.data,
                  order: order,
                );
              },
            ),
            const SizedBox(height: 14),
            if (canRetryPayment ||
                canCancel ||
                canConfirmReceive ||
                canReview ||
                canRequestRefund) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final shouldStack = constraints.maxWidth < 420;
                  final actions = <Widget>[
                    if (canRetryPayment)
                      _buildOrderAction(
                        shouldStack: shouldStack,
                        child: ElevatedButton.icon(
                          onPressed: () => _retryPayment(context),
                          icon: const Icon(AppIcons.receipt),
                          label: Text(
                            context.translate('pay_now'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    if (canCancel)
                      _buildOrderAction(
                        shouldStack: shouldStack,
                        child: OutlinedButton(
                          onPressed: () => _confirmStatusChange(
                            context,
                            status: 'Cancelled',
                            title: context.translate('cancel_order_title'),
                            message: context.translate('cancel_order_msg'),
                            successMessage: context.translate(
                              'order_cancelled_msg',
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                          child: Text(
                            context.translate('cancel_order'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    if (canConfirmReceive)
                      _buildOrderAction(
                        shouldStack: shouldStack,
                        child: ElevatedButton(
                          onPressed: () => _confirmStatusChange(
                            context,
                            status: 'Received',
                            title: context.translate('confirm_delivery'),
                            message: context.translate('confirm_delivery_msg'),
                            successMessage: context.translate(
                              'order_received_msg',
                            ),
                          ),
                          child: Text(
                            context.translate('mark_received'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    if (!canConfirmReceive && canReview)
                      _buildOrderAction(
                        shouldStack: shouldStack,
                        child: OutlinedButton(
                          onPressed: () {
                            if (order.items.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WriteReviewPage(
                                    product: order.items.first.product,
                                  ),
                                ),
                              );
                            }
                          },
                          child: Text(
                            context.translate('write_review_btn'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ];

                  if (shouldStack) {
                    return Column(
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          actions[i],
                          if (i < actions.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                    );
                  }

                  return Row(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        actions[i],
                        if (i < actions.length - 1) const SizedBox(width: 12),
                      ],
                    ],
                  );
                },
              ),
              if (canRequestRefund) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showRefundRequestDialog(context),
                    icon: const Icon(AppIcons.receipt),
                    label: Text(context.translate('request_refund')),
                  ),
                ),
              ],
              const SizedBox(height: 14),
            ],
            if (!canReview || canConfirmReceive || canCancel)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      AppIcons.shipping,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getDeliveryStatusText(context, order.status),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? AppIcons.caretLeft
                          : AppIcons.caretRight,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.45,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getDeliveryStatusText(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return context.translate('awaiting_confirmation');
      case 'shipped':
        return context.translate('on_its_way');
      case 'delivered':
        return context.translate('package_delivered');
      case 'processing':
        return context.translate('seller_preparing');
      case 'received':
        return context.translate('you_confirmed_delivery');
      case 'cancelled':
        return context.translate('order_is_cancelled');
      default:
        return context.translate('est_delivery_days');
    }
  }

  bool _canCancel(String status) {
    final normalized = status.toLowerCase();
    return normalized == 'pending' || normalized == 'processing';
  }

  bool _canRetryPayment(Order order) {
    // Online checkout remains disabled until order creation and payment flows
    // are fully aligned on the backend.
    return false;
  }

  Future<void> _retryPayment(BuildContext context) async {
    try {
      final response = await SupabaseService.client.functions.invoke(
        'create-chargily-checkout',
        body: {'orderId': order.id},
      );

      final data = response.data;
      if (data is! Map) {
        throw Exception('Invalid checkout response from server');
      }

      final payload = Map<String, dynamic>.from(data);
      final checkoutUrl = payload['checkoutUrl']?.toString();
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('Missing checkout URL from payment gateway');
      }

      final uri = Uri.tryParse(checkoutUrl);
      if (uri == null) {
        throw Exception('Invalid checkout URL');
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('Could not open payment page');
      }
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizeErrorMessage(context, e)),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _showRefundRequestDialog(BuildContext context) async {
    final reasonController = TextEditingController();
    final detailsController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.translate('request_refund')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: context.translate('report_reason'),
                hintText: context.translate('refund_reason_hint'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailsController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.translate('report_details'),
                hintText: context.translate('refund_details_hint'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.translate('submit')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await sl<OrderRepository>().submitRefundRequest(
          orderId: order.id,
          reason: reasonController.text.trim(),
          details: detailsController.text.trim().isEmpty
              ? null
              : detailsController.text.trim(),
        );
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.translate('refund_request_submitted')),
            backgroundColor: AppColors.success,
          ),
        );
      } catch (e) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizeErrorMessage(context, e)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    reasonController.dispose();
    detailsController.dispose();
  }

  Future<void> _confirmStatusChange(
    BuildContext context, {
    required String status,
    required String title,
    required String message,
    required String successMessage,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.translate('no')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.translate('yes')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await sl<OrderRepository>().updateOrderStatus(
          orderId: order.id,
          newStatus: status,
        );
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      } catch (e) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizeErrorMessage(context, e)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildOrderAction({required bool shouldStack, required Widget child}) {
    if (shouldStack) {
      return SizedBox(width: double.infinity, child: child);
    }
    return Expanded(child: child);
  }
}

Future<_ShipmentSummary?> _loadShipmentSummary(String orderId) async {
  final rows = await SupabaseService.client
      .from('shipment_tracking')
      .select()
      .eq('orderId', orderId)
      .order('eventAt', ascending: false)
      .limit(1);

  final shipments = List<Map<String, dynamic>>.from(rows);
  if (shipments.isEmpty) {
    return null;
  }

  return _ShipmentSummary.fromMap(shipments.first);
}

class _ShipmentSummaryCard extends StatelessWidget {
  const _ShipmentSummaryCard({required this.summary, required this.order});

  final _ShipmentSummary? summary;
  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.shipping, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.translate('shipment_tracking'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (summary == null)
            Text(
              context.translate('shipment_pending'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
            if (summary!.isTrackingPending) ...[
              Text(
                context.translate('tracking_pending'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
            ] else ...[
              _ShipmentMetaRow(
                label: context.translate('tracking_number'),
                value: summary!.trackingNumber,
              ),
              const SizedBox(height: 6),
            ],
            _ShipmentMetaRow(
              label: context.translate('carrier_label'),
              value: summary!.carrierName,
            ),
            const SizedBox(height: 6),
            _ShipmentMetaRow(
              label: context.translate('delivery_status'),
              value: _shipmentStatusLabel(context, summary!.status),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderTrackingPage(order: order),
                    ),
                  );
                },
                child: Text(context.translate('view_tracking')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShipmentMetaRow extends StatelessWidget {
  const _ShipmentMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShipmentSummary {
  const _ShipmentSummary({
    required this.trackingNumber,
    required this.carrierName,
    required this.status,
    required this.notes,
  });

  final String trackingNumber;
  final String carrierName;
  final String status;
  final String notes;

  bool get isTrackingPending =>
      notes.toLowerCase().contains('tracking number pending');

  factory _ShipmentSummary.fromMap(Map<String, dynamic> map) {
    return _ShipmentSummary(
      trackingNumber: (map['trackingNumber'] ?? '').toString(),
      carrierName: (map['carrierName'] ?? 'elogistia').toString(),
      status: (map['status'] ?? 'ready_to_ship').toString(),
      notes: (map['notes'] ?? '').toString(),
    );
  }
}

String _shipmentStatusLabel(BuildContext context, String status) {
  switch (status.toLowerCase()) {
    case 'ready_to_ship':
    case 'processing':
      return context.translate('processing_filter');
    case 'shipped':
      return context.translate('shipped_filter');
    case 'out_for_delivery':
      return context.translate('on_its_way');
    case 'delivered':
      return context.translate('delivered_filter');
    case 'returned':
      return context.translate('order_is_cancelled');
    case 'failed_delivery':
      return context.translate('shipment_failed');
    default:
      return status;
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'received':
        color = Colors.green;
        break;
      case 'processing':
        color = Colors.blue;
        break;
      case 'shipped':
        color = Colors.indigo;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 96),
        child: Text(
          _getStatusLabel(context, status).toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  String _getStatusLabel(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return context.translate('pending');
      case 'processing':
        return context.translate('processing_filter');
      case 'shipped':
        return context.translate('shipped_filter');
      case 'delivered':
        return context.translate('delivered_filter');
      case 'received':
        return context.translate('mark_received');
      case 'cancelled':
        return context.translate('cancelled_filter');
      default:
        return status;
    }
  }
}
