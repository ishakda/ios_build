import 'package:flutter/material.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/core/constants/app_constants.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/localization/localized_error_message.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_empty_state.dart';
import 'package:untitled1/core/widgets/product_card.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';
import 'package:untitled1/features/product/presentation/bloc/product_bloc.dart';
import 'package:untitled1/features/product/presentation/bloc/product_event.dart';
import 'package:untitled1/features/product/presentation/bloc/product_state.dart';
import 'package:untitled1/features/product/presentation/pages/product_details_page.dart';

class ProductListingPage extends StatefulWidget {
  const ProductListingPage({super.key, required this.categoryName});

  final String categoryName;

  @override
  State<ProductListingPage> createState() => _ProductListingPageState();
}

class _ProductListingPageState extends State<ProductListingPage> {
  double _minPrice = 0;
  double _maxPrice = 300000;
  double _minRating = 0;
  bool _inStockOnly = false;
  _ListingSort _sort = _ListingSort.relevance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductBloc>().add(
        FetchProductsByCategory(widget.categoryName),
      );
    });
  }

  List<Product> _applyFilters(List<Product> source) {
    var list = source.where((p) {
      final price = p.discountPrice ?? p.price;
      if (price < _minPrice || price > _maxPrice) return false;
      if (_minRating > 0 && p.rating < _minRating) return false;
      if (_inStockOnly && p.stock <= 0) return false;
      return true;
    }).toList();

    switch (_sort) {
      case _ListingSort.relevance:
        break;
      case _ListingSort.priceLowHigh:
        list.sort(
          (a, b) => (a.discountPrice ?? a.price).compareTo(
            b.discountPrice ?? b.price,
          ),
        );
      case _ListingSort.priceHighLow:
        list.sort(
          (a, b) => (b.discountPrice ?? b.price).compareTo(
            a.discountPrice ?? a.price,
          ),
        );
      case _ListingSort.ratingHigh:
        list.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return AppGradientScaffold(
      appBar: AppBar(
        title: Text(
          AppConstants.getCategoryDisplay(context, widget.categoryName),
        ),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.filter),
            onPressed: () => _showFilterSheet(context),
          ),
          PopupMenuButton<_ListingSort>(
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _ListingSort.relevance,
                child: Text(context.translate('sort_relevance')),
              ),
              PopupMenuItem(
                value: _ListingSort.priceLowHigh,
                child: Text(context.translate('sort_price_low_high')),
              ),
              PopupMenuItem(
                value: _ListingSort.priceHighLow,
                child: Text(context.translate('sort_price_high_low')),
              ),
              PopupMenuItem(
                value: _ListingSort.ratingHigh,
                child: Text(context.translate('sort_rating_high')),
              ),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, state) {
          if (state is ProductLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ProductError) {
            return AppEmptyState(
              icon: AppIcons.warning,
              title: context.translate('products_unavailable'),
              subtitle: localizeErrorMessage(context, state.message),
            );
          }
          if (state is! ProductLoaded) {
            return const SizedBox.shrink();
          }

          final products = _applyFilters(state.products);
          if (products.isEmpty) {
            return AppEmptyState(
              icon: AppIcons.search,
              title: context.translate('no_products_found'),
              subtitle: context.translate('search_no_results_msg'),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return ProductCard(
                product: product,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProductDetailsPage(product: product),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    double tempMin = _minPrice;
    double tempMax = _maxPrice;
    double tempRating = _minRating;
    bool tempStock = _inStockOnly;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.translate('filter_results'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(context.translate('price_range')),
                  RangeSlider(
                    values: RangeValues(tempMin, tempMax),
                    min: 0,
                    max: 300000,
                    divisions: 60,
                    labels: RangeLabels(
                      tempMin.toStringAsFixed(0),
                      tempMax.toStringAsFixed(0),
                    ),
                    onChanged: (v) => setSheetState(() {
                      tempMin = v.start;
                      tempMax = v.end;
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(context.translate('rating_any')),
                  Slider(
                    value: tempRating,
                    min: 0,
                    max: 5,
                    divisions: 5,
                    label: tempRating.toStringAsFixed(0),
                    onChanged: (v) => setSheetState(() => tempRating = v),
                  ),
                  SwitchListTile(
                    value: tempStock,
                    onChanged: (v) => setSheetState(() => tempStock = v),
                    title: Text(context.translate('in_stock_only')),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _minPrice = tempMin;
                          _maxPrice = tempMax;
                          _minRating = tempRating;
                          _inStockOnly = tempStock;
                        });
                        Navigator.pop(context);
                      },
                      child: Text(context.translate('apply_filters')),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

enum _ListingSort { relevance, priceLowHigh, priceHighLow, ratingHigh }
