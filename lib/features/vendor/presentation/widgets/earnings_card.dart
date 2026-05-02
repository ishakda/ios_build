import 'package:flutter/material.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/theme/app_colors.dart';

class EarningsCard extends StatelessWidget {
  final double totalEarnings;
  final int pendingOrders;
  final int completedOrders;
  final int weeklyViews;
  final int weeklyClicks;
  final int weeklySalesCount;
  final String? topProductName;
  final double ctr;
  final double clickToCartRate;
  final double cartToPurchaseRate;
  final double overallPurchaseRate;
  final int lowStockCount;

  const EarningsCard({
    super.key,
    required this.totalEarnings,
    required this.pendingOrders,
    required this.completedOrders,
    required this.weeklyViews,
    required this.weeklyClicks,
    required this.weeklySalesCount,
    this.topProductName,
    this.ctr = 0,
    this.clickToCartRate = 0,
    this.cartToPurchaseRate = 0,
    this.overallPurchaseRate = 0,
    this.lowStockCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.translate('total_earnings'),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '${totalEarnings.toStringAsFixed(0)} ${context.translate('dzd')}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat(
                context,
                context.translate('pending'),
                pendingOrders.toString(),
              ),
              Container(width: 1, height: 30, color: Colors.white24),
              _buildMiniStat(
                context,
                context.translate('completed'),
                completedOrders.toString(),
              ),
              Container(width: 1, height: 30, color: Colors.white24),
              _buildMiniStat(context, context.translate('rating'), '4.8'),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildPill(context, context.translate('weekly_views'), '$weeklyViews'),
              _buildPill(context, context.translate('weekly_clicks'), '$weeklyClicks'),
              _buildPill(context, context.translate('weekly_sales'), '$weeklySalesCount'),
              _buildPill(context, context.translate('ctr_label'), '${ctr.toStringAsFixed(1)}%'),
              _buildPill(
                context,
                context.translate('click_to_cart'),
                '${clickToCartRate.toStringAsFixed(1)}%',
              ),
              _buildPill(
                context,
                context.translate('cart_to_purchase'),
                '${cartToPurchaseRate.toStringAsFixed(1)}%',
              ),
              _buildPill(
                context,
                context.translate('purchase_rate'),
                '${overallPurchaseRate.toStringAsFixed(1)}%',
              ),
              _buildPill(context, context.translate('low_stock_alert'), '$lowStockCount'),
              if (topProductName != null && topProductName!.isNotEmpty)
                _buildPill(
                  context,
                  context.translate('top_product'),
                  topProductName!,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPill(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
