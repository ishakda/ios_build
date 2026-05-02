import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_empty_state.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_state.dart';
import 'package:untitled1/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';
import 'package:untitled1/features/product/domain/repositories/product_repository.dart';
import 'package:untitled1/features/product/presentation/bloc/wishlist_bloc.dart';
import 'package:untitled1/features/product/presentation/pages/product_details_page.dart';
import 'package:untitled1/injection_container.dart';

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _insight;
  List<Product> _results = const [];
  List<Product> _allProducts = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runAssistant([String? forcedQuery]) async {
    final query = (forcedQuery ?? _controller.text).trim();
    if (query.isEmpty || _isLoading) {
      return;
    }
    setState(() {
      _isLoading = true;
      _insight = null;
    });

    if (_allProducts.isEmpty) {
      final result = await sl<ProductRepository>().getProducts();
      if (!mounted) {
        return;
      }
      result.fold((_) {}, (products) => _allProducts = products);
    }

    final assistantResult = _SmartProductAssistant.search(
      products: _allProducts,
      query: query,
      localizations: AppLocalizations.of(context)!,
      preferredCategories: _preferredCategories(),
      preferredBrands: _preferredBrands(),
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _results = assistantResult.products;
      _insight = assistantResult.summary;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final l10n = AppLocalizations.of(context)!;
    final userName = authState is Authenticated
        ? authState.user.name
        : l10n.translate('there');

    return AppGradientScaffold(
      appBar: AppBar(title: Text(l10n.translate('ai_shopping_assistant'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              AppSurfaceCard(
                padding: const EdgeInsets.all(16),
                radius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('ai_intro').replaceAll('{name}', userName),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _runAssistant(),
                            decoration: InputDecoration(
                              hintText: l10n.translate('ai_query_hint'),
                              prefixIcon: const Icon(AppIcons.sparkles),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _runAssistant,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(l10n.translate('ask')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          [
                            l10n.translate('ai_prompt_best_phone_camera'),
                            l10n.translate('ai_prompt_cheap_headphones'),
                            l10n.translate('ai_prompt_laptop_students'),
                            l10n.translate('ai_prompt_fashion_women'),
                          ].map((prompt) {
                            return _PromptChip(prompt: prompt);
                          }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_insight != null)
                AppSurfaceCard(
                  padding: const EdgeInsets.all(14),
                  radius: 18,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        AppIcons.sparkles,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _insight!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Expanded(
                child: _results.isEmpty
                    ? AppEmptyState(
                        icon: AppIcons.sparkles,
                        title: l10n.translate('ai_no_suggestions'),
                        subtitle: l10n.translate('ai_no_suggestions_subtitle'),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final product = _results[index];
                          return AppSurfaceCard(
                            radius: 18,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  product.imageUrl,
                                  width: 54,
                                  height: 54,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 54,
                                    height: 54,
                                    color: AppColors.greyLight,
                                    alignment: Alignment.center,
                                    child: const Icon(AppIcons.imageBroken),
                                  ),
                                ),
                              ),
                              title: Text(
                                product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              subtitle: Text(
                                '${(product.discountPrice ?? product.price).toStringAsFixed(0)} DZD • ${product.rating.toStringAsFixed(1)}★',
                              ),
                              trailing: const Icon(AppIcons.caretRight),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProductDetailsPage(product: product),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Set<String> _preferredCategories() {
    final categories = <String>{};
    final wishlistItems = context.read<WishlistBloc>().state.items;
    final cartItems = context.read<CartBloc>().state.items;

    for (final product in wishlistItems) {
      categories.add(product.category.toLowerCase());
      if (product.parentCategory != null) {
        categories.add(product.parentCategory!.toLowerCase());
      }
    }
    for (final item in cartItems) {
      categories.add(item.product.category.toLowerCase());
      if (item.product.parentCategory != null) {
        categories.add(item.product.parentCategory!.toLowerCase());
      }
    }
    return categories;
  }

  Set<String> _preferredBrands() {
    final brands = <String>{};
    final wishlistItems = context.read<WishlistBloc>().state.items;
    final cartItems = context.read<CartBloc>().state.items;

    for (final product in wishlistItems) {
      final brand = product.brand;
      if ((brand ?? '').trim().isNotEmpty) {
        brands.add(brand!.toLowerCase());
      }
    }
    for (final item in cartItems) {
      final brand = item.product.brand;
      if ((brand ?? '').trim().isNotEmpty) {
        brands.add(brand!.toLowerCase());
      }
    }
    return brands;
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.prompt});

  final String prompt;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(prompt),
      onPressed: () {
        final state = context.findAncestorStateOfType<_AiAssistantPageState>();
        if (state == null) {
          return;
        }
        state._controller.text = prompt;
        state._runAssistant(prompt);
      },
    );
  }
}

class _AssistantResult {
  const _AssistantResult({required this.summary, required this.products});

  final String summary;
  final List<Product> products;
}

class _SmartProductAssistant {
  static _AssistantResult search({
    required List<Product> products,
    required String query,
    required AppLocalizations localizations,
    Set<String> preferredCategories = const {},
    Set<String> preferredBrands = const {},
  }) {
    if (products.isEmpty) {
      return _AssistantResult(
        summary: localizations.translate('ai_products_not_loaded'),
        products: [],
      );
    }

    final normalized = query.toLowerCase().trim();
    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();

    final wantsBudget =
        normalized.contains('cheap') || normalized.contains('budget');
    final wantsQuality =
        normalized.contains('best') ||
        normalized.contains('top') ||
        normalized.contains('quality');
    final wantsFast =
        normalized.contains('fast') || normalized.contains('quick');
    final priceLimit = _extractPriceLimit(tokens);

    final scored = products.map((product) {
      final text = '${product.name} ${product.description} ${product.category}'
          .toLowerCase();
      var score = 0.0;

      for (final token in tokens) {
        if (text.contains(token)) {
          score += 2.0;
        }
      }
      if (wantsQuality) {
        score += product.rating * 1.2;
        score += math.min(product.reviewsCount.toDouble(), 100) / 25;
      }
      if (preferredCategories.isNotEmpty) {
        final category = product.category.toLowerCase();
        final parentCategory = (product.parentCategory ?? '').toLowerCase();
        if (preferredCategories.contains(category) ||
            preferredCategories.contains(parentCategory)) {
          score += 2.2;
        }
      }
      if (preferredBrands.isNotEmpty &&
          preferredBrands.contains((product.brand ?? '').toLowerCase())) {
        score += 1.8;
      }
      if (wantsBudget) {
        final price = product.discountPrice ?? product.price;
        score += 150000 / math.max(price, 1);
      }
      if (wantsFast) {
        score += product.stock > 0 ? 2 : -2;
      }
      if (priceLimit != null &&
          (product.discountPrice ?? product.price) > priceLimit) {
        score -= 8;
      }

      return (product: product, score: score);
    }).toList()..sort((a, b) => b.score.compareTo(a.score));

    final top = scored
        .where((item) => item.score > 0)
        .take(6)
        .map((item) => item.product)
        .toList();

    final summary = top.isEmpty
        ? localizations.translate('ai_no_strong_matches')
        : priceLimit != null
        ? localizations
              .translate('ai_found_matches_with_budget')
              .replaceAll('{count}', top.length.toString())
              .replaceAll('{price}', priceLimit.toStringAsFixed(0))
        : localizations
              .translate('ai_found_matches')
              .replaceAll('{count}', top.length.toString());

    return _AssistantResult(summary: summary, products: top);
  }

  static double? _extractPriceLimit(List<String> tokens) {
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i].replaceAll(RegExp(r'[^0-9.]'), '');
      final value = double.tryParse(token);
      if (value != null && value > 0) {
        return value;
      }
    }
    return null;
  }
}
