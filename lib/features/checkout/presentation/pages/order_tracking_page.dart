import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/localization/localized_error_message.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/features/checkout/domain/entities/order.dart';

class OrderTrackingPage extends StatefulWidget {
  const OrderTrackingPage({super.key, required this.order});

  final Order order;

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  late Future<List<_ShipmentEvent>> _trackingFuture;
  bool _isSyncing = false;

  Order get order => widget.order;

  @override
  void initState() {
    super.initState();
    _trackingFuture = _loadTracking();
  }

  Future<List<_ShipmentEvent>> _loadTracking() async {
    try {
      await SupabaseService.client.functions.invoke(
        'sync-elogistia-tracking',
        body: {'orderId': order.id},
      );
    } catch (_) {}

    final rows = await SupabaseService.client
        .from('shipment_tracking')
        .select()
        .eq('orderId', order.id)
        .order('eventAt');

    return List<Map<String, dynamic>>.from(
      rows,
    ).map(_ShipmentEvent.fromMap).toList();
  }

  Future<void> _syncTracking() async {
    if (_isSyncing) {
      return;
    }
    setState(() => _isSyncing = true);
    try {
      await SupabaseService.client.functions.invoke(
        'sync-elogistia-tracking',
        body: {'orderId': order.id},
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _trackingFuture = _loadTracking();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('tracking_synced'))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .translate('tracking_sync_failed')
                .replaceAll('{error}', localizeErrorMessage(context, error)),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusSteps = _buildStatusSteps(order.status);
    final currentStepIndex = statusSteps.indexWhere(
      (s) => s.toLowerCase() == order.status.toLowerCase(),
    );

    return AppGradientScaffold(
      appBar: AppBar(
        title: Text(
          context.translate('track_order'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderInfo(context),
            const SizedBox(height: 24),
            _buildShipmentSection(context),
            const SizedBox(height: 40),
            Text(
              context.translate('order_status'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            _buildStepper(context, statusSteps, currentStepIndex),
            const SizedBox(height: 40),
            Text(
              context.translate('order_items'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildItemsList(context),
          ],
        ),
      ),
    );
  }

  List<String> _buildStatusSteps(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const ['Pending', 'Processing', 'Shipped', 'Delivered'];
      case 'received':
        return const ['Processing', 'Shipped', 'Delivered', 'Received'];
      case 'cancelled':
        return const ['Processing', 'Cancelled'];
      default:
        return const ['Processing', 'Shipped', 'Delivered'];
    }
  }

  Widget _buildOrderInfo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white12
              : AppColors.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            context,
            context.translate('order_id'),
            '#${order.displayNumber}',
          ),
          const Divider(height: 24),
          _buildInfoRow(
            context,
            context.translate('date'),
            DateFormat('dd MMM yyyy, HH:mm').format(order.orderDate),
          ),
          const Divider(height: 24),
          _buildInfoRow(
            context,
            context.translate('total_amount'),
            '${order.totalAmount.toStringAsFixed(0)} ${context.translate('dzd')}',
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildShipmentSection(BuildContext context) {
    return FutureBuilder<List<_ShipmentEvent>>(
      future: _trackingFuture,
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <_ShipmentEvent>[];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (events.isEmpty) {
          return AppSurfaceCard(
            padding: const EdgeInsets.all(18),
            child: Text(context.translate('shipment_updates_unavailable')),
          );
        }

        final latest = events.last;
        return AppSurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.translate('shipment_tracking'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: OutlinedButton.icon(
                  onPressed: _isSyncing ? null : _syncTracking,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.history, size: 16),
                  label: Text(context.translate('sync_tracking')),
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                context,
                context.translate('carrier_label'),
                latest.carrierName,
              ),
              const Divider(height: 24),
              _buildInfoRow(
                context,
                context.translate('tracking_number'),
                latest.trackingNumber,
                isBold: true,
              ),
              const Divider(height: 24),
              _buildInfoRow(
                context,
                context.translate('delivery_status'),
                _humanizeShipmentStatus(context, latest.status),
                isBold: true,
              ),
              const SizedBox(height: 14),
              ...events.reversed
                  .take(5)
                  .map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.notes,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy, HH:mm',
                                  ).format(event.eventAt),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white60 : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepper(
    BuildContext context,
    List<String> steps,
    int currentStep,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: steps.length,
      itemBuilder: (context, index) {
        final isActive = index <= currentStep;
        final isLast = index == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary
                        : (isDark ? Colors.white10 : Colors.grey[200]),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive
                          ? AppColors.primary
                          : (isDark ? Colors.white24 : Colors.grey[300]!),
                      width: 2,
                    ),
                  ),
                  child: isActive
                      ? const Icon(
                          AppIcons.check,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: index < currentStep
                        ? AppColors.primary
                        : (isDark ? Colors.white10 : Colors.grey[200]),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getStatusLabel(context, steps[index]),
                    style: TextStyle(
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isActive
                          ? (isDark ? Colors.white : AppColors.textPrimary)
                          : (isDark ? Colors.white38 : Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getStatusDescription(context, steps[index]),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _getStatusDescription(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return context.translate('awaiting_confirmation');
      case 'processing':
        return context.translate('seller_preparing');
      case 'shipped':
        return context.translate('on_its_way');
      case 'delivered':
        return context.translate('package_delivered');
      case 'received':
        return context.translate('you_confirmed_delivery');
      case 'cancelled':
        return context.translate('order_is_cancelled');
      default:
        return '';
    }
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

  String _humanizeShipmentStatus(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'ready_to_ship':
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
        return context.translate('orders_unavailable');
      default:
        return status;
    }
  }

  Widget _buildItemsList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: order.items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.product.imageUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${context.translate('qty')}: ${item.quantity}',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white60
                                : AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(item.product.price * item.quantity).toStringAsFixed(0)} ${context.translate('dzd')}',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ShipmentEvent {
  const _ShipmentEvent({
    required this.trackingNumber,
    required this.carrierName,
    required this.status,
    required this.notes,
    required this.eventAt,
  });

  final String trackingNumber;
  final String carrierName;
  final String status;
  final String notes;
  final DateTime eventAt;

  factory _ShipmentEvent.fromMap(Map<String, dynamic> map) {
    return _ShipmentEvent(
      trackingNumber: (map['trackingNumber'] ?? '').toString(),
      carrierName: (map['carrierName'] ?? 'elogistia').toString(),
      status: (map['status'] ?? 'processing').toString(),
      notes: (map['notes'] ?? map['status'] ?? '').toString(),
      eventAt: SupabaseService.parseDateTime(map['eventAt']),
    );
  }
}
