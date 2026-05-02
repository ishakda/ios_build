import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/core/constants/app_constants.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/localization/localized_error_message.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_empty_state.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/core/widgets/product_card.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';
import 'package:untitled1/features/product/domain/repositories/product_repository.dart';
import 'package:untitled1/features/product/presentation/bloc/product_bloc.dart';
import 'package:untitled1/features/product/presentation/bloc/product_event.dart';
import 'package:untitled1/features/product/presentation/bloc/product_state.dart';
import 'package:untitled1/features/product/presentation/pages/product_details_page.dart';
import 'package:untitled1/features/search/presentation/pages/search_page.dart';
import 'package:untitled1/injection_container.dart';

enum _CategorySort { newest, priceLowHigh, priceHighLow, ratingHigh, popular }

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  late String _selectedTopCategory;
  late String _selectedCatalogKey;
  _CategorySort _sort = _CategorySort.newest;
  double _minRating = 0;
  bool _inStockOnly = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCategory;
    _selectedTopCategory = _resolveTopCategory(
      initial ?? AppConstants.topCategoryNames.first,
    );
    _selectedCatalogKey = initial ?? _selectedTopCategory;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) {
      return;
    }
    _loaded = true;
    _loadCategory();
  }

  String _resolveTopCategory(String category) {
    if (AppConstants.isTopCategory(category)) {
      return category;
    }
    for (final entry in AppConstants.categoryTree.entries) {
      final hasMatch = entry.value.any((sub) => sub['name'] == category);
      if (hasMatch) {
        return entry.key;
      }
    }
    return AppConstants.topCategoryNames.first;
  }

  void _loadCategory() {
    context.read<ProductBloc>().add(
      FetchProductsByCategory(_selectedCatalogKey),
    );
  }

  List<Product> _sortProducts(List<Product> products) {
    var sorted = [...products];
    if (_minRating > 0) {
      sorted = sorted.where((product) => product.rating >= _minRating).toList();
    }
    if (_inStockOnly) {
      sorted = sorted.where((product) => product.stock > 0).toList();
    }

    switch (_sort) {
      case _CategorySort.newest:
        sorted.sort((a, b) => b.id.compareTo(a.id));
      case _CategorySort.priceLowHigh:
        sorted.sort(
          (a, b) => (a.discountPrice ?? a.price).compareTo(
            b.discountPrice ?? b.price,
          ),
        );
      case _CategorySort.priceHighLow:
        sorted.sort(
          (a, b) => (b.discountPrice ?? b.price).compareTo(
            a.discountPrice ?? a.price,
          ),
        );
      case _CategorySort.ratingHigh:
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
      case _CategorySort.popular:
        sorted.sort((a, b) {
          final scoreB = (b.rating * 10) + b.reviewsCount;
          final scoreA = (a.rating * 10) + a.reviewsCount;
          return scoreB.compareTo(scoreA);
        });
    }
    return sorted;
  }

  void _selectTopCategory(String category) {
    setState(() {
      _selectedTopCategory = category;
      _selectedCatalogKey = category;
    });
    _loadCategory();
  }

  void _selectCatalogKey(String category) {
    setState(() => _selectedCatalogKey = category);
    _loadCategory();
  }

  void _openProduct(BuildContext context, Product product) {
    sl<ProductRepository>()
        .trackProductEvent(
          productId: product.id,
          eventType: 'click',
          viewerId: SupabaseService.currentUserId,
        )
        .catchError((_) {});
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subcategories = AppConstants.categoryTree[_selectedTopCategory] ?? [];
    final categoryColor =
        (subcategories.isNotEmpty
                ? subcategories.first['color']
                : Colors.blueGrey)
            as Color;

    return AppGradientScaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SearchPage()),
          ),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  AppIcons.search,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.translate('search_hint'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Row(
          children: [
            SizedBox(
              width: 112,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
                itemCount: AppConstants.topCategoryNames.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final category = AppConstants.topCategoryNames[index];
                  final data = AppConstants.categoryTree[category]!.first;
                  final selected = _selectedTopCategory == category;
                  final color = data['color'] as Color;
                  return _CategoryRailTile(
                    label: AppConstants.getCategoryDisplay(context, category),
                    icon: data['icon'] as IconData,
                    color: color,
                    selected: selected,
                    onTap: () => _selectTopCategory(category),
                  );
                },
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 12, 24),
                child: ListView(
                  children: [
                    AppSurfaceCard(
                      padding: const EdgeInsets.all(16),
                      radius: 28,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () =>
                                _selectCatalogKey(_selectedTopCategory),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _selectedCatalogKey == _selectedTopCategory
                                    ? categoryColor.withValues(alpha: 0.12)
                                    : theme.colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color:
                                      _selectedCatalogKey ==
                                          _selectedTopCategory
                                      ? categoryColor.withValues(alpha: 0.28)
                                      : theme.colorScheme.outline.withValues(
                                          alpha: 0.1,
                                        ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      context.translate('all_products'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  Icon(
                                    Directionality.of(context) ==
                                            TextDirection.rtl
                                        ? AppIcons.caretLeft
                                        : AppIcons.caretRight,
                                    size: 18,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  AppConstants.getCategoryDisplay(
                                    context,
                                    _selectedTopCategory,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                context.translate('see_all'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 0.48,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                            itemCount: subcategories.length,
                            itemBuilder: (context, index) {
                              final item = subcategories[index];
                              final name = item['name'] as String;
                              final selected = _selectedCatalogKey == name;
                              return _SubcategoryTile(
                                label: AppConstants.getCategoryDisplay(
                                  context,
                                  name,
                                ),
                                icon: item['icon'] as IconData,
                                color: item['color'] as Color,
                                selected: selected,
                                onTap: () => _selectCatalogKey(name),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppSurfaceCard(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      radius: 24,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  AppConstants.getCategoryDisplay(
                                    context,
                                    _selectedCatalogKey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              PopupMenuButton<_CategorySort>(
                                initialValue: _sort,
                                onSelected: (value) =>
                                    setState(() => _sort = value),
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: _CategorySort.newest,
                                    child: Text(
                                      context.translate('sort_newest'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _CategorySort.priceLowHigh,
                                    child: Text(
                                      context.translate('sort_price_low_high'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _CategorySort.priceHighLow,
                                    child: Text(
                                      context.translate('sort_price_high_low'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _CategorySort.ratingHigh,
                                    child: Text(
                                      context.translate('sort_rating_high'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _CategorySort.popular,
                                    child: Text(
                                      context.translate('sort_popular'),
                                    ),
                                  ),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(AppIcons.filter, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        context.translate('filter_results'),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 38,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                FilterChip(
                                  selected: _minRating >= 4,
                                  showCheckmark: false,
                                  label: Text(
                                    context.translate('rating_4_plus'),
                                  ),
                                  onSelected: (selected) {
                                    setState(() {
                                      _minRating = selected ? 4 : 0;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  selected: _inStockOnly,
                                  showCheckmark: false,
                                  label: Text(
                                    context.translate('in_stock_only'),
                                  ),
                                  onSelected: (selected) {
                                    setState(() {
                                      _inStockOnly = selected;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    BlocBuilder<ProductBloc, ProductState>(
                      builder: (context, state) {
                        if (state is ProductLoading) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (state is ProductError) {
                          return AppEmptyState(
                            icon: AppIcons.warning,
                            title: context.translate('error'),
                            subtitle: localizeErrorMessage(
                              context,
                              state.message,
                            ),
                          );
                        }
                        if (state is! ProductLoaded || state.products.isEmpty) {
                          return AppEmptyState(
                            icon: AppIcons.bagOpen,
                            title: context.translate('no_items'),
                            subtitle: context.translate('try_another_category'),
                          );
                        }

                        final products = _sortProducts(state.products);
                        return GridView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.54,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return ProductCard(
                              product: product,
                              onTap: () => _openProduct(context, product),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRailTile extends StatelessWidget {
  const _CategoryRailTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.surface
                : theme.colorScheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(22),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 4,
                height: 84,
                decoration: BoxDecoration(
                  color: selected ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 14,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected
                              ? color.withValues(alpha: 0.14)
                              : theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          size: 18,
                          color: selected ? color : theme.hintColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubcategoryTile extends StatelessWidget {
  const _SubcategoryTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.28)
                : theme.colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: selected ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
