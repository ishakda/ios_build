import 'package:flutter/material.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/localization/localized_error_message.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_empty_state.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_state.dart';
import 'package:untitled1/features/checkout/presentation/bloc/order_bloc.dart';
import 'package:untitled1/features/checkout/presentation/bloc/order_event.dart';
import 'package:untitled1/features/checkout/presentation/bloc/order_state.dart';
import 'package:untitled1/features/checkout/presentation/pages/order_tracking_page.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      context.read<OrderBloc>().add(StreamBuyerOrders(authState.user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppGradientScaffold(
      appBar: AppBar(title: Text(context.translate('my_orders'))),
      body: BlocBuilder<OrderBloc, OrderState>(
        builder: (context, state) {
          if (state is OrdersLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is OrderError) {
            return AppEmptyState(
              icon: AppIcons.warning,
              title: context.translate('orders_unavailable'),
              subtitle: localizeErrorMessage(context, state.message),
            );
          } else if (state is OrdersLoaded) {
            if (state.orders.isEmpty) {
              return AppEmptyState(
                icon: AppIcons.bagOpen,
                title: context.translate('no_orders_yet'),
                subtitle: context.translate('order_history_desc'),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.orders.length,
              itemBuilder: (context, index) {
                final order = state.orders[index];
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${context.translate('order_number_short')} ${order.displayNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          _buildStatusChip(context, order.status),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white10
                                  : AppColors.greyLight,
                              borderRadius: BorderRadius.circular(8),
                              image:
                                  order.items.isNotEmpty &&
                                      order
                                          .items
                                          .first
                                          .product
                                          .images
                                          .isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(
                                        order.items.first.product.images.first,
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child:
                                order.items.isEmpty ||
                                    order.items.first.product.images.isEmpty
                                ? const Icon(AppIcons.imageBroken)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.items.length == 1
                                      ? order.items.first.product.name
                                      : '${order.items.first.product.name} + ${order.items.length - 1} more',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${context.translate('placed_on')} ${DateFormat('dd MMM yyyy').format(order.orderDate)}',
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
                            '${order.totalAmount.toStringAsFixed(0)} ${context.translate('dzd')}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderTrackingPage(order: order),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark
                                ? Colors.white
                                : AppColors.primary,
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white24
                                  : AppColors.primary,
                            ),
                          ),
                          child: Text(context.translate('view_details')),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    final normalizedStatus = status.toLowerCase();
    final color = switch (normalizedStatus) {
      'delivered' || 'received' => Colors.green,
      'shipped' => Colors.indigo,
      'cancelled' => Colors.redAccent,
      'processing' => AppColors.primary,
      _ => Colors.orange,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
