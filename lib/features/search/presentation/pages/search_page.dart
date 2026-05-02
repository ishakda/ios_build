import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/core/constants/app_constants.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_empty_state.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:untitled1/core/widgets/app_page_intro_card.dart';
import 'package:untitled1/core/widgets/product_card.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';
import 'package:untitled1/features/product/domain/repositories/product_repository.dart';
import 'package:untitled1/features/product/presentation/bloc/product_bloc.dart';
import 'package:untitled1/features/product/presentation/bloc/product_event.dart';
import 'package:untitled1/features/product/presentation/bloc/product_state.dart';
import 'package:untitled1/features/product/presentation/pages/categories_page.dart';
import 'package:untitled1/features/product/presentation/pages/product_details_page.dart';
import 'package:untitled1/injection_container.dart';

enum _SearchSort { relevance, priceLowHigh, priceHighLow, ratingHigh }

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _recentSearches = [
    'rolex',
    'headphones',
    'laptop',
    'fashion',
  ];
  final List<String> _suggestions = [];
  List<Product> _allProducts = const [];
  List<Product> _liveResults = const [];
  bool _isSearching = false;
  _SearchSort _sort = _SearchSort.relevance;
  String _selectedCategory = 'All';
  double _minRating = 0;
  double? _maxPrice;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    context.read<ProductBloc>().add(const FetchProducts());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _updateSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 170), () {
      if (!mounted) {
        return;
      }
      final normalized = query.trim().toLowerCase();
      setState(() {
        _isSearching = normalized.isNotEmpty;
        _suggestions
          ..clear()
          ..addAll(_computeSuggestions(normalized));
        _liveResults = _applyFiltersAndSort(_filterProducts(normalized));
      });
    });
  }

  List<String> _computeSuggestions(String query) {
    if (query.isEmpty) {
      return const [];
    }

    final values = <String>{};
    for (final product in _allProducts) {
      final name = product.name.trim();
      final category = product.category.trim();
      if (name.toLowerCase().contains(query)) {
        values.add(name);
      }
      if (category.toLowerCase().contains(query)) {
        values.add(category);
      }
    }
    return values.take(6).toList();
  }

  List<Product> _filterProducts(String query) {
    if (query.isEmpty) {
      return const [];
    }

    final tokens = query
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    return _allProducts.where((product) {
      final haystack =
          '${product.name} ${product.description} ${product.category} ${product.brand ?? ''} ${product.parentCategory ?? ''} ${product.subCategory ?? ''}'
              .toLowerCase();
      return tokens.every(haystack.contains);
    }).toList();
  }

  List<Product> _applyFiltersAndSort(List<Product> products) {
    var filtered = products;
    if (_selectedCategory != 'All') {
      filtered = filtered
          .where((product) => product.category == _selectedCategory)
          .toList();
    }
    if (_minRating > 0) {
      filtered = filtered
          .where((product) => product.rating >= _minRating)
          .toList();
    }
    if (_maxPrice != null) {
      filtered = filtered
          .where(
            (product) => (product.discountPrice ?? product.price) <= _maxPrice!,
          )
          .toList();
    }

    final sorted = [...filtered];
    switch (_sort) {
      case _SearchSort.relevance:
        break;
      case _SearchSort.priceLowHigh:
        sorted.sort(
          (a, b) => (a.discountPrice ?? a.price).compareTo(
            b.discountPrice ?? b.price,
          ),
        );
      case _SearchSort.priceHighLow:
        sorted.sort(
          (a, b) => (b.discountPrice ?? b.price).compareTo(
            a.discountPrice ?? a.price,
          ),
        );
      case _SearchSort.ratingHigh:
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
    }

    return sorted;
  }

  void _openProduct(Product product) {
    sl<ProductRepository>()
        .trackProductEvent(
          productId: product.id,
          eventType: 'click',
          viewerId: SupabaseService.currentUserId,
        )
        .catchError((_) {});
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsPage(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductBloc, ProductState>(
      listener: (context, state) {
        if (state is ProductLoaded) {
          setState(() {
            _allProducts = state.products;
            if (_searchController.text.trim().isNotEmpty) {
              _updateSearch(_searchController.text);
            }
          });
        }
      },
      child: AppGradientScaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              if (!_isSearching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: AppPageIntroCard(
                    title: context.translate('discover_products'),
                    subtitle: context.translate('search_discover_subtitle'),
                    trailing: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        AppIcons.search,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              if (_isSearching && _suggestions.isNotEmpty)
                _buildSuggestions(context),
              if (_isSearching) _buildFilterToolbar(context),
              Expanded(
                child: _isSearching
                    ? _buildSearchResults()
                    : _buildSearchHistory(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
      child: Row(
        children: [
          _CircleActionButton(
            icon: AppIcons.back,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: _updateSearch,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: context.translate('search_on_sahla'),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        AppIcons.search,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(AppIcons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _updateSearch('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, index) {
          final suggestion = _suggestions[index];
          return ActionChip(
            label: Text(suggestion),
            onPressed: () {
              _searchController.text = suggestion;
              _updateSearch(suggestion);
            },
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: _suggestions.length,
      ),
    );
  }

  Widget _buildSearchHistory(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.translate('recent_searches'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _recentSearches
                .map(
                  (search) => ActionChip(
                    label: Text(search),
                    onPressed: () {
                      _searchController.text = search;
                      _updateSearch(search);
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          Text(
            context.translate('popular_categories'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...[
            ('Phones', AppIcons.categoryPhones),
            ('Fashion', AppIcons.categoryFashion),
            ('Home', AppIcons.categoryHome),
            ('Electronics', AppIcons.categoryElectronics),
          ].map(
            (entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(entry.$2, color: AppColors.primary, size: 20),
              title: Text(AppConstants.getCategoryDisplay(context, entry.$1)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoriesPage(initialCategory: entry.$1),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_liveResults.isEmpty) {
      return AppEmptyState(
        icon: AppIcons.search,
        title: context.translate('no_products_found'),
        subtitle: context.translate('search_no_results_msg'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _liveResults.length,
      itemBuilder: (context, index) {
        final product = _liveResults[index];
        return ProductCard(
          product: product,
          onTap: () => _openProduct(product),
        );
      },
    );
  }

  Widget _buildFilterToolbar(BuildContext context) {
    final categories = <String>{'All'};
    for (final product in _allProducts) {
      if (product.category.trim().isNotEmpty) {
        categories.add(product.category);
      }
    }
    final orderedCategories = categories.toList()..sort();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      borderRadius: BorderRadius.circular(14),
                      items: orderedCategories
                          .map(
                            (category) => DropdownMenuItem<String>(
                              value: category,
                              child: Text(
                                category == 'All'
                                    ? context.translate('all')
                                    : AppConstants.getCategoryDisplay(
                                        context,
                                        category,
                                      ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedCategory = value);
                        _updateSearch(_searchController.text);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  PopupMenuButton<_SearchSort>(
                    initialValue: _sort,
                    onSelected: (value) {
                      setState(() => _sort = value);
                      _updateSearch(_searchController.text);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _SearchSort.relevance,
                        child: Text(context.translate('sort_relevance')),
                      ),
                      PopupMenuItem(
                        value: _SearchSort.priceLowHigh,
                        child: Text(context.translate('sort_price_low_high')),
                      ),
                      PopupMenuItem(
                        value: _SearchSort.priceHighLow,
                        child: Text(context.translate('sort_price_high_low')),
                      ),
                      PopupMenuItem(
                        value: _SearchSort.ratingHigh,
                        child: Text(context.translate('sort_rating_high')),
                      ),
                    ],
                    child: _FilterChip(
                      icon: AppIcons.filter,
                      label: context.translate('sort_label'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  PopupMenuButton<double>(
                    initialValue: _minRating == 0 ? null : _minRating,
                    onSelected: (value) {
                      setState(() => _minRating = value);
                      _updateSearch(_searchController.text);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 0,
                        child: Text(context.translate('rating_any')),
                      ),
                      PopupMenuItem(
                        value: 3,
                        child: Text(context.translate('rating_3_plus')),
                      ),
                      PopupMenuItem(
                        value: 4,
                        child: Text(context.translate('rating_4_plus')),
                      ),
                    ],
                    child: _FilterChip(
                      icon: AppIcons.star,
                      label: _minRating <= 0
                          ? context.translate('rating_any')
                          : '${_minRating.toStringAsFixed(0)}+',
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: context.translate('clear'),
            onPressed: () {
              setState(() {
                _sort = _SearchSort.relevance;
                _selectedCategory = 'All';
                _minRating = 0;
                _maxPrice = null;
              });
              _updateSearch(_searchController.text);
            },
            icon: const Icon(AppIcons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

class _CircleActionButton extends StatefulWidget {
  const _CircleActionButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  State<_CircleActionButton> createState() => _CircleActionButtonState();
}

class _CircleActionButtonState extends State<_CircleActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.diagonal3Values(
          _isPressed ? 0.9 : 1.0,
          _isPressed ? 0.9 : 1.0,
          1.0,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.18),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            widget.icon,
            color: theme.colorScheme.onSurface,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
