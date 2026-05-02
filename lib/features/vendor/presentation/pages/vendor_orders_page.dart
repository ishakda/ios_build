import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/localization/localized_error_message.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_empty_state.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:untitled1/core/widgets/app_page_intro_card.dart';
import 'package:untitled1/core/widgets/app_section_header.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/features/checkout/domain/entities/order.dart'
    as entity;
import 'package:untitled1/features/checkout/presentation/pages/order_tracking_page.dart';
import 'package:untitled1/features/vendor/presentation/cubit/vendor_orders_cubit.dart';
import 'package:untitled1/features/vendor/presentation/cubit/vendor_orders_state.dart';
import 'package:untitled1/injection_container.dart';

class VendorOrdersPage extends StatefulWidget {
  const VendorOrdersPage({super.key});

  @override
  State<VendorOrdersPage> createState() => _VendorOrdersPageState();
}

class _VendorOrdersPageState extends State<VendorOrdersPage> {
  static const _filters = [
    'All',
    'Pending',
    'Processing',
    'Shipped',
    'Delivered',
    'Cancelled',
  ];

  String _getFilterKey(String filter) {
    switch (filter) {
      case 'All':
        return 'all';
      case 'Pending':
        return 'pending_filter';
      case 'Processing':
        return 'processing_filter';
      case 'Shipped':
        return 'shipped_filter';
      case 'Delivered':
        return 'delivered_filter';
      case 'Received':
        return 'delivered_filter';
      case 'Cancelled':
        return 'cancelled_filter';
      default:
        return filter.toLowerCase();
    }
  }

  late final String? _currentUserId;
  late final VendorOrdersCubit _vendorOrdersCubit;
  final Set<String> _creatingShipmentOrderIds = <String>{};

  @override
  void initState() {
    super.initState();
    _currentUserId = SupabaseService.currentUserId;
    _vendorOrdersCubit = sl<VendorOrdersCubit>();
    final currentUserId = _currentUserId;
    if (currentUserId != null) {
      _vendorOrdersCubit.loadOrders(currentUserId);
    }
  }

  @override
  void dispose() {
    _vendorOrdersCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppGradientScaffold(
      appBar: AppBar(
        title: Text(
          context.translate('store_orders'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: _currentUserId == null
          ? AppEmptyState(
              icon: AppIcons.store,
              title: context.translate('no_orders_sign_in'),
              subtitle: context.translate('sign_in_seller_desc'),
            )
          : BlocProvider.value(
              value: _vendorOrdersCubit,
              child: BlocConsumer<VendorOrdersCubit, VendorOrdersState>(
                listener: (context, state) {
                  if (state.actionErrorMessage != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          localizeErrorMessage(
                            context,
                            state.actionErrorMessage,
                            fallbackKey: 'update_order_failed',
                          ),
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  if (state.isLoading && state.orders.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.errorMessage != null && state.orders.isEmpty) {
                    return AppEmptyState(
                      icon: AppIcons.warning,
                      title: context.translate('orders_unavailable'),
                      subtitle: state.errorMessage!,
                      accentColor: Colors.redAccent,
                    );
                  }

                  final filteredOrders = state.filteredOrders;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: AppPageIntroCard(
                          title: context.translate('store_orders'),
                          trailing: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              AppIcons.orders,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      _buildStatusFilter(context, state),
                      Expanded(
                        child: filteredOrders.isEmpty
                            ? AppEmptyState(
                                icon: AppIcons.orders,
                                title: state.orders.isEmpty
                                    ? context.translate('no_orders_found')
                                    : context
                                          .translate('no_status_orders_store')
                                          .replaceAll(
                                            '{status}',
                                            context.translate(
                                              _getFilterKey(
                                                state.selectedFilter,
                                              ),
                                            ),
                                          ),
                                subtitle: state.orders.isEmpty
                                    ? context.translate(
                                        'store_orders_empty_msg',
                                      )
                                    : context.translate(
                                        'try_different_filter_msg',
                                      ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: filteredOrders.length,
                                itemBuilder: (context, index) {
                                  return _buildOrderCard(
                                    context,
                                    state,
                                    filteredOrders[index],
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _buildStatusFilter(BuildContext context, VendorOrdersState state) {
    return SizedBox(
      height: 76,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        children: _filters.map((filter) {
          final isSelected = state.selectedFilter == filter;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: ChoiceChip(
              selected: isSelected,
              label: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  context.translate(_getFilterKey(filter)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              onSelected: (_) =>
                  context.read<VendorOrdersCubit>().updateFilter(filter),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    VendorOrdersState state,
    entity.Order order,
  ) {
    final statusColor = _getStatusColor(order.status);
    final sellerItems = order.items
        .where((item) => item.product.sellerId == _currentUserId)
        .toList();
    final totalForSeller = sellerItems.fold<double>(
      0,
      (total, item) => total + (item.product.price * item.quantity),
    );

    return AppSurfaceCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppSectionHeader(
                  title:
                      '${context.translate('order_id_prefix')}${order.displayNumber}',
                  subtitle: DateFormat(
                    'MMM dd, yyyy - hh:mm a',
                  ).format(order.orderDate),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    context.translate(_getFilterKey(order.status)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...sellerItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      item.product.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 60,
                        height: 60,
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        alignment: Alignment.center,
                        child: const Icon(AppIcons.bagOpen),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${context.translate('qty_prefix')}${item.quantity} - ${item.product.price.toInt()} ${context.translate('dzd')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 28),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: MediaQuery.sizeOf(context).width < 360 ? 220 : 260,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(AppIcons.user, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        order.buyerName?.isNotEmpty == true
                            ? '${context.translate('buyer_name')}: ${order.buyerName}'
                            : '${context.translate('buyer_id_prefix')}${order.buyerId.substring(0, 5)}...',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.translate('seller_subtotal'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${totalForSeller.toInt()} ${context.translate('dzd')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(AppIcons.phone, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${context.translate('buyer_phone')}: ${order.buyerPhone ?? context.translate('not_set')}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (order.shippingAddressSummary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(AppIcons.mapPin, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${context.translate('shipping_address')}: ${order.shippingAddressSummary}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          FutureBuilder<_ShipmentSummary?>(
            future: _loadShipmentSummary(order.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              return _buildShipmentCard(context, order, summary: snapshot.data);
            },
          ),
          if (order.status == 'Pending' || order.status == 'Processing') ...[
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final shouldStack = constraints.maxWidth < 420;
                final cancelButton = _buildActionSlot(
                  shouldStack: shouldStack,
                  child: OutlinedButton(
                    onPressed: state.isUpdating
                        ? null
                        : () => _confirmSellerAction(
                            context,
                            order: order,
                            newStatus: 'Cancelled',
                            title: context.translate('cancel_this_order'),
                            message: context.translate(
                              'cancel_order_notify_msg',
                            ),
                          ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    child: Text(
                      context.translate('cancel'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
                final shipButton = _buildActionSlot(
                  shouldStack: shouldStack,
                  child: ElevatedButton(
                    onPressed: state.isUpdating
                        ? null
                        : () => context
                              .read<VendorOrdersCubit>()
                              .updateOrderStatus(
                                orderId: order.id,
                                buyerId: order.buyerId,
                                newStatus: 'Shipped',
                              ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.45,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      state.isUpdating
                          ? context.translate('updating_btn')
                          : context.translate('mark_as_shipped'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );

                if (shouldStack) {
                  return Column(
                    children: [
                      cancelButton,
                      const SizedBox(height: 10),
                      shipButton,
                    ],
                  );
                }

                return Row(
                  children: [
                    cancelButton,
                    const SizedBox(width: 12),
                    shipButton,
                  ],
                );
              },
            ),
          ] else if (order.status == 'Shipped') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isUpdating
                    ? null
                    : () => _confirmSellerAction(
                        context,
                        order: order,
                        newStatus: 'Delivered',
                        title: context.translate('mark_order_delivered_title'),
                        message: context.translate('mark_order_delivered_msg'),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  disabledBackgroundColor: Colors.green.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  state.isUpdating
                      ? context.translate('updating_btn')
                      : context.translate('mark_as_delivered'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.08, end: 0);
  }

  Widget _buildShipmentCard(
    BuildContext context,
    entity.Order order, {
    required _ShipmentSummary? summary,
  }) {
    final theme = Theme.of(context);
    final isCreating = _creatingShipmentOrderIds.contains(order.id);
    final canCreateShipment =
        summary == null && order.status.toLowerCase() != 'cancelled';

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
            if (summary.isTrackingPending) ...[
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
                value: summary.trackingNumber,
              ),
              const SizedBox(height: 6),
            ],
            _ShipmentMetaRow(
              label: context.translate('carrier_label'),
              value: summary.carrierName,
            ),
            const SizedBox(height: 6),
            _ShipmentMetaRow(
              label: context.translate('delivery_status'),
              value: _shipmentStatusLabel(context, summary.status),
            ),
          ],
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final shouldStack = constraints.maxWidth < 420;
              final actions = <Widget>[
                if (summary != null)
                  _buildActionSlot(
                    shouldStack: shouldStack,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                OrderTrackingPage(order: order),
                          ),
                        );
                      },
                      child: Text(
                        context.translate('view_tracking'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (canCreateShipment)
                  _buildActionSlot(
                    shouldStack: shouldStack,
                    child: ElevatedButton.icon(
                      onPressed: isCreating
                          ? null
                          : () => _createShipmentForOrder(context, order.id),
                      icon: isCreating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(AppIcons.shipping, size: 16),
                      label: Text(
                        context.translate('retry_shipment_creation'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ];

              if (actions.isEmpty) {
                return const SizedBox.shrink();
              }

              if (shouldStack) {
                return Column(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      actions[i],
                      if (i < actions.length - 1) const SizedBox(height: 10),
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
        ],
      ),
    );
  }

  Future<void> _createShipmentForOrder(
    BuildContext context,
    String orderId,
  ) async {
    if (_creatingShipmentOrderIds.contains(orderId)) {
      return;
    }

    setState(() {
      _creatingShipmentOrderIds.add(orderId);
    });

    var progressShown = false;
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    if (context.mounted) {
      progressShown = true;
      showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(context.translate('creating_shipment'))),
              ],
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    try {
      final orderResponse = await SupabaseService.client
          .from('orders')
          .select('deliveryType')
          .eq('id', orderId)
          .single();
      
      final carrierId = orderResponse['deliveryType'] == 'stopdesk' || 
                        orderResponse['deliveryType'] == 'home' 
                        ? 'elogistia' : orderResponse['deliveryType'];

      final response = await SupabaseService.client.functions
          .invoke('create-shipment', body: {
            'orderId': orderId,
            'carrierId': carrierId ?? 'elogistia',
          })
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw Exception('Shipment creation timed out.'),
          );
      final data = response.data;
      if (data is! Map) {
        throw Exception('Invalid shipment response from server');
      }

      final payload = Map<String, dynamic>.from(data);
      final errorMessage = payload['error']?.toString().trim();
      if (errorMessage != null && errorMessage.isNotEmpty) {
        throw Exception(errorMessage);
      }

      if (!context.mounted) {
        return;
      }

      final trackingNumber = payload['trackingNumber']?.toString().trim();
      final snackBarMessage = (trackingNumber != null && trackingNumber.isNotEmpty)
          ? '${context.translate('shipment_created')}: $trackingNumber'
          : context.translate('shipment_created');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(snackBarMessage)),
      );
      setState(() {});
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .translate('shipment_creation_failed')
                .replaceAll('{error}', localizeErrorMessage(context, error)),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        if (progressShown) {
          try {
            rootNavigator.pop();
          } catch (_) {}
        }
        setState(() {
          _creatingShipmentOrderIds.remove(orderId);
        });
      }
    }
  }

  Future<void> _confirmSellerAction(
    BuildContext context, {
    required entity.Order order,
    required String newStatus,
    required String title,
    required String message,
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
      context.read<VendorOrdersCubit>().updateOrderStatus(
        orderId: order.id,
        buyerId: order.buyerId,
        newStatus: newStatus,
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Processing':
        return Colors.blue;
      case 'Shipped':
        return Colors.indigo;
      case 'Delivered':
      case 'Received':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildActionSlot({required bool shouldStack, required Widget child}) {
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
