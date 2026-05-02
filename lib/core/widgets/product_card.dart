import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:untitled1/core/constants/app_constants.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_smart_image.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';
import 'package:untitled1/features/product/presentation/bloc/wishlist_bloc.dart';
import 'package:untitled1/features/product/presentation/bloc/wishlist_event.dart';
import 'package:untitled1/features/product/presentation/bloc/wishlist_state.dart';

class ProductCard extends StatefulWidget {
  const ProductCard({super.key, required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectivePrice = widget.product.discountPrice ?? widget.product.price;

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isHovered = true),
          onTapUp: (_) => setState(() => _isHovered = false),
          onTapCancel: () => setState(() => _isHovered = false),
          onTap: widget.onTap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 285;
              return AnimatedContainer(
                duration: 180.ms,
                curve: Curves.easeOut,
                transform: Matrix4.diagonal3Values(
                  _isHovered ? 1.02 : 1,
                  _isHovered ? 1.02 : 1,
                  1,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: colorScheme.outline.withValues(
                      alpha: _isHovered ? 0.22 : 0.12,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: _isHovered ? 0.08 : 0.04,
                      ),
                      blurRadius: _isHovered ? 24 : 16,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: compact ? 11 : 12,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ColoredBox(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.22),
                                child: Padding(
                                  padding: EdgeInsets.all(compact ? 10 : 12),
                                  child: AppSmartImage(
                                    url: widget.product.imageUrl,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.product.discountPrice != null)
                              PositionedDirectional(
                                top: 10,
                                end: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFE3D3),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '-${widget.product.discountPercentage.toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      color: Color(0xFFCD6C1E),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            PositionedDirectional(
                              top: 8,
                              start: 8,
                              child: BlocBuilder<WishlistBloc, WishlistState>(
                                builder: (context, state) {
                                  final isFavorite = state.items.any(
                                    (item) => item.id == widget.product.id,
                                  );
                                  return IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: colorScheme.surface
                                          .withValues(alpha: 0.92),
                                      foregroundColor: colorScheme.onSurface,
                                      padding: const EdgeInsets.all(8),
                                      minimumSize: const Size(34, 34),
                                    ),
                                    icon: Icon(
                                      isFavorite
                                          ? AppIcons.wishlistActive
                                          : AppIcons.wishlist,
                                      color: isFavorite
                                          ? AppColors.accent
                                          : colorScheme.onSurfaceVariant,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      context.read<WishlistBloc>().add(
                                        ToggleWishlist(widget.product),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: compact ? 10 : 9,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            12,
                            compact ? 8 : 10,
                            12,
                            compact ? 10 : 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    (compact
                                            ? theme.textTheme.bodySmall
                                            : theme.textTheme.bodyMedium)
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          height: 1.15,
                                        ),
                              ),
                              SizedBox(height: compact ? 4 : 6),
                              Text(
                                AppConstants.getCategoryDisplay(
                                  context,
                                  widget.product.category,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: compact ? 11 : null,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${effectivePrice.toStringAsFixed(2)} ${context.translate('dzd')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    (compact
                                            ? theme.textTheme.titleSmall
                                            : theme.textTheme.titleMedium)
                                        ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              if (widget.product.discountPrice != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '${widget.product.price.toStringAsFixed(2)} ${context.translate('dzd')}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: compact ? 10 : null,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ),
                              SizedBox(height: compact ? 6 : 8),
                              Row(
                                children: [
                                  const Icon(
                                    AppIcons.star,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.product.rating.toStringAsFixed(1),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: compact ? 11 : null,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    width: compact ? 30 : 34,
                                    height: compact ? 30 : 34,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      AppIcons.plus,
                                      size: compact ? 14 : 16,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
