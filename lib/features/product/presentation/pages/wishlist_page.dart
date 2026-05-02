import 'package:flutter/material.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_empty_state.dart';
import 'package:untitled1/core/widgets/app_section_header.dart';
import 'package:untitled1/core/widgets/product_card.dart';
import 'package:untitled1/features/product/presentation/bloc/wishlist_bloc.dart';
import 'package:untitled1/features/product/presentation/bloc/wishlist_state.dart';
import 'package:untitled1/features/product/presentation/pages/product_details_page.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppGradientScaffold(
      appBar: AppBar(title: Text(context.translate('my_wishlist'))),
      body: BlocBuilder<WishlistBloc, WishlistState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return AppEmptyState(
              icon: AppIcons.wishlist,
              title: context.translate('wishlist_empty_plain'),
              subtitle: context.translate('wishlist_empty_plain_subtitle'),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionHeader(
                title: context.translate('saved_picks'),
                subtitle: context
                    .translate('wishlist_items_ready')
                    .replaceAll('{count}', '${state.items.length}'),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    final product = state.items[index];
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

