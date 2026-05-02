import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/localization/localized_error_message.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/product_card.dart';
import 'package:untitled1/features/product/presentation/bloc/product_bloc.dart';
import 'package:untitled1/features/product/presentation/bloc/product_event.dart';
import 'package:untitled1/features/product/presentation/bloc/product_state.dart';
import 'package:untitled1/features/product/presentation/pages/product_details_page.dart';
import 'package:untitled1/features/product/presentation/widgets/filter_bottom_sheet.dart';

class ProductSearchDelegate extends SearchDelegate {
  final ProductBloc productBloc;

  ProductSearchDelegate({required this.productBloc});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(AppIcons.filter),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => const FilterBottomSheet(),
          );
        },
      ),
      IconButton(
        icon: const Icon(AppIcons.close),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(AppIcons.back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    productBloc.add(SearchProducts(query));

    return BlocBuilder<ProductBloc, ProductState>(
      bloc: productBloc,
      builder: (context, state) {
        if (state is ProductLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is ProductLoaded) {
          if (state.products.isEmpty) {
            return Center(child: Text(context.translate('no_products_found')));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: state.products.length,
            itemBuilder: (context, index) {
              final product = state.products[index];
              return ProductCard(
                product: product,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailsPage(product: product),
                  ),
                ),
              );
            },
          );
        } else if (state is ProductError) {
          return Center(
            child: Text(localizeErrorMessage(context, state.message)),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // This could be improved with real suggestions from a database or search history
    if (query.isEmpty) {
      return Center(child: Text(context.translate('search_products_prompt')));
    }

    productBloc.add(SearchProducts(query));

    return BlocBuilder<ProductBloc, ProductState>(
      bloc: productBloc,
      builder: (context, state) {
        if (state is ProductLoaded) {
          final suggestions = state.products
              .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
          return ListView.builder(
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final product = suggestions[index];
              return ListTile(
                leading: Image.network(
                  product.imageUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
                title: Text(product.name),
                subtitle: Text(product.category),
                onTap: () {
                  query = product.name;
                  showResults(context);
                },
              );
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
