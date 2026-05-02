import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_empty_state.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:untitled1/core/widgets/app_page_intro_card.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/core/constants/app_constants.dart';
import 'package:untitled1/features/cart/domain/entities/cart_item.dart';
import 'package:untitled1/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:untitled1/features/cart/presentation/bloc/cart_event.dart';
import 'package:untitled1/features/cart/presentation/bloc/cart_state.dart';
import 'package:untitled1/features/checkout/presentation/pages/checkout_page.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppGradientScaffold(
      appBar: AppBar(title: Text(context.translate('my_cart'))),
      body: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return AppEmptyState(
              icon: AppIcons.bagOpen,
              title: context.translate('cart_empty_title'),
              subtitle: context.translate('cart_empty_subtitle'),
              actionLabel: context.translate('start_shopping'),
              onAction: () => Navigator.pop(context),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 10),
                child: AppPageIntroCard(
                  title: context.translate('review_items'),
                  subtitle:
                      '${state.items.length} ${context.translate('items_ready_checkout')}',
                  trailing: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      AppIcons.cartActive,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: state.items.length,
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
                  itemBuilder: (context, index) {
                    return _CartItemTile(item: state.items[index])
                        .animate()
                        .fadeIn(delay: (index * 90).ms)
                        .slideX(begin: 0.08, end: 0);
                  },
                ),
              ),
              _CartSummary(total: state.totalPrice),
            ],
          );
        },
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;

  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppSurfaceCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      radius: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              item.product.imageUrl,
              width: 88,
              height: 88,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        AppIcons.trash,
                        color: AppColors.error,
                        size: 18,
                      ),
                      onPressed: () => context.read<CartBloc>().add(
                        RemoveFromCart(item.product.id),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  AppConstants.getCategoryDisplay(
                    context,
                    item.product.category,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 240;
                    final price = Text(
                      '${(item.product.discountPrice ?? item.product.price).toStringAsFixed(0)} ${context.translate('dzd')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    );
                    final qtyControls = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _QtyButton(
                          icon: AppIcons.minus,
                          onTap: () => context.read<CartBloc>().add(
                            UpdateQuantity(item.product.id, -1),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '${item.quantity}',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        _QtyButton(
                          icon: AppIcons.plus,
                          onTap: () => context.read<CartBloc>().add(
                            UpdateQuantity(item.product.id, 1),
                          ),
                        ),
                      ],
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          price,
                          const SizedBox(height: 10),
                          qtyControls,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: price),
                        const SizedBox(width: 8),
                        qtyControls,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 16, color: theme.colorScheme.onSurface),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final double total;

  const _CartSummary({required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 20, 24, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.translate('total'),
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${total.toStringAsFixed(0)} ${context.translate('dzd')}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CheckoutPage(),
                    ),
                  );
                },
                child: Text(context.translate('checkout')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
