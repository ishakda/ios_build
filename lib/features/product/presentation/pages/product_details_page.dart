import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:share_plus/share_plus.dart';
import 'package:untitled1/core/constants/app_constants.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:untitled1/core/widgets/app_page_intro_card.dart';
import 'package:untitled1/core/widgets/app_smart_image.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/core/widgets/product_card.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';
import 'package:untitled1/features/auth/domain/repositories/auth_repository.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_state.dart';
import 'package:untitled1/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:untitled1/features/cart/presentation/bloc/cart_event.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';
import 'package:untitled1/features/product/domain/entities/review.dart';
import 'package:untitled1/features/product/domain/repositories/product_repository.dart';
import 'package:untitled1/features/product/presentation/bloc/recently_viewed_bloc.dart';
import 'package:untitled1/features/product/presentation/bloc/recently_viewed_event.dart';
import 'package:untitled1/features/product/presentation/bloc/wishlist_bloc.dart';
import 'package:untitled1/features/product/presentation/bloc/wishlist_event.dart';
import 'package:untitled1/features/product/presentation/bloc/wishlist_state.dart';
import 'package:untitled1/features/product/presentation/pages/write_review_page.dart';
import 'package:untitled1/features/checkout/presentation/pages/checkout_page.dart';
import 'package:untitled1/features/vendor/presentation/pages/vendor_store_page.dart';
import 'package:untitled1/injection_container.dart';

class ProductDetailsPage extends StatefulWidget {
  const ProductDetailsPage({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  _DetailsTab _selectedTab = _DetailsTab.overview;
  int _currentImageIndex = 0;
  User? _seller;
  List<Review> _reviews = [];
  bool _canReview = false;
  bool _isLoadingReviews = true;
  late Future<List<Product>> _similarProductsFuture;

  List<String> get _galleryImages {
    final images = widget.product.images.isNotEmpty
        ? widget.product.images
        : [widget.product.imageUrl];
    return images.where((url) => url.isNotEmpty).toList();
  }

  int get _reviewCount =>
      _reviews.isNotEmpty ? _reviews.length : widget.product.reviewsCount;

  double get _displayRating {
    if (_reviews.isNotEmpty) {
      final total = _reviews.fold<double>(
        0,
        (sum, review) => sum + review.rating,
      );
      return total / _reviews.length;
    }
    return widget.product.rating;
  }

  String _getStoreDisplayName(BuildContext context) {
    final seller = _seller;
    if (seller == null) {
      return context.translate('seller_store');
    }
    return seller.storeName?.trim().isNotEmpty == true
        ? seller.storeName!
        : '${seller.name} ${context.translate('seller_store')}';
  }

  String _getStoreDescription(BuildContext context) {
    final seller = _seller;
    if (seller == null) {
      return context.translate('discover_seller_products');
    }
    return seller.storeDescription?.trim().isNotEmpty == true
        ? seller.storeDescription!
        : context.translate('discover_seller_products');
  }

  @override
  void initState() {
    super.initState();
    _fetchSeller();
    _fetchReviews();
    _checkCanReview();
    _trackProductEvent('view');
    _similarProductsFuture = _loadSimilarProducts();
    Future.microtask(() {
      if (mounted) {
        context.read<RecentlyViewedBloc>().add(
          AddToRecentlyViewed(widget.product),
        );
      }
    });
  }

  Future<void> _fetchSeller() async {
    final sellerId = widget.product.sellerId;
    if (sellerId == null || sellerId.isEmpty) {
      return;
    }

    final result = await sl<AuthRepository>().getUserById(sellerId);
    if (!mounted) {
      return;
    }
    result.fold(
      (_) {},
      (user) => setState(() {
        _seller = user;
      }),
    );
  }

  Future<void> _fetchReviews() async {
    final result = await sl<ProductRepository>().getProductReviews(
      widget.product.id,
    );
    if (!mounted) {
      return;
    }
    result.fold(
      (_) => setState(() {
        _reviews = const [];
        _isLoadingReviews = false;
      }),
      (reviews) => setState(() {
        _reviews = reviews;
        _isLoadingReviews = false;
      }),
    );
  }

  Future<void> _checkCanReview() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      return;
    }

    final result = await sl<ProductRepository>().hasUserPurchasedProduct(
      authState.user.id,
      widget.product.id,
    );
    if (!mounted) {
      return;
    }
    result.fold(
      (_) {},
      (canReview) => setState(() {
        _canReview = canReview;
      }),
    );
  }

  Future<void> _showAddReviewPage() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WriteReviewPage(product: widget.product),
      ),
    );

    if (result == true) {
      await _fetchReviews();
    }
  }

  Future<void> _trackProductEvent(String type) async {
    try {
      final authState = context.read<AuthBloc>().state;
      final viewerId = authState is Authenticated
          ? authState.user.id
          : SupabaseService.currentUserId;
      await sl<ProductRepository>().trackProductEvent(
        productId: widget.product.id,
        eventType: type,
        viewerId: viewerId,
      );
    } catch (_) {
      // Analytics should never block UI behavior.
    }
  }

  Future<List<Product>> _loadSimilarProducts() async {
    final result = await sl<ProductRepository>().getProductsByCategory(
      widget.product.category,
    );
    return result.fold(
      (_) => const <Product>[],
      (products) => products
          .where((product) => product.id != widget.product.id)
          .take(10)
          .toList(),
    );
  }

  Future<void> _shareProduct() async {
    final effectivePrice = widget.product.discountPrice ?? widget.product.price;
    final shareText = context
        .translate('product_share_template')
        .replaceAll('{name}', widget.product.name)
        .replaceAll('{description}', widget.product.description)
        .replaceAll('{price}', effectivePrice.toStringAsFixed(0))
        .replaceAll('{currency}', context.translate('dzd'))
        .replaceAll(
          '{category}',
          AppConstants.getCategoryDisplay(context, widget.product.category),
        );

    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: widget.product.name,
          title: widget.product.name,
        ),
      );
      if (result.status == ShareResultStatus.success) {
        await _trackProductEvent('share');
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('unable_share_product'))),
      );
    }
  }

  Future<void> _reportProduct() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('sign_in_report_products'))),
      );
      return;
    }

    final reasonController = TextEditingController();
    final detailsController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.translate('report_product')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: context.translate('report_reason'),
                hintText: context.translate('report_reason_hint'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailsController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.translate('report_details'),
                hintText: context.translate('report_details_hint'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.translate('submit')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final result = await sl<ProductRepository>().reportProduct(
        productId: widget.product.id,
        reason: reasonController.text.trim(),
        details: detailsController.text.trim().isEmpty
            ? null
            : detailsController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      result.fold(
        (failure) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: Colors.redAccent,
          ),
        ),
        (_) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.translate('product_report_submitted')),
            backgroundColor: AppColors.success,
          ),
        ),
      );
    }

    reasonController.dispose();
    detailsController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectivePrice = widget.product.discountPrice ?? widget.product.price;

    return AppGradientScaffold(
      appBar: AppBar(
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(AppIcons.share),
            onPressed: _shareProduct,
          ),
          IconButton(
            icon: const Icon(AppIcons.warning),
            onPressed: _reportProduct,
          ),
          BlocBuilder<WishlistBloc, WishlistState>(
            builder: (context, state) {
              final isFavorite = state.items.any(
                (item) => item.id == widget.product.id,
              );
              return IconButton(
                icon: Icon(
                  isFavorite ? AppIcons.wishlistActive : AppIcons.wishlist,
                  color: isFavorite ? Colors.red : null,
                ),
                onPressed: () {
                  context.read<WishlistBloc>().add(
                    ToggleWishlist(widget.product),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 132),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGallery(theme),
              const SizedBox(height: 14),
              _buildSellerStoreBanner(context),
              const SizedBox(height: 16),
              AppPageIntroCard(
                title: widget.product.name,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    '${effectivePrice.toStringAsFixed(0)} ${context.translate('dzd')}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AppSurfaceCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaBadge(
                          icon: AppIcons.categoryAll,
                          label: AppConstants.getCategoryDisplay(
                            context,
                            widget.product.category,
                          ),
                        ),
                        _MetaBadge(
                          icon: AppIcons.star,
                          label: '${_displayRating.toStringAsFixed(1)} / 5',
                          accentColor: Colors.amber,
                        ),
                        _MetaBadge(
                          icon: AppIcons.review,
                          label:
                              '$_reviewCount ${context.translate('reviews')}',
                        ),
                        _MetaBadge(
                          icon: AppIcons.orders,
                          label: widget.product.stock > 0
                              ? '${widget.product.stock} ${context.translate('in_stock')}'
                              : context.translate('out_of_stock'),
                          accentColor: widget.product.stock > 0
                              ? AppColors.success
                              : Colors.redAccent,
                        ),
                      ],
                    ),
                    if (widget.product.discountPrice != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${widget.product.price.toStringAsFixed(0)} ${context.translate('dzd')}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _buildTabSelector(context),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _buildSelectedSection(context),
              ),
              const SizedBox(height: 16),
              _buildSimilarProductsSection(context),
            ],
          ),
        ),
      ),
      bottomSheet: _buildBottomBar(context),
    );
  }

  Widget _buildTabSelector(BuildContext context) {
    final tabs = [
      (_DetailsTab.overview, context.translate('overview')),
      (_DetailsTab.specs, context.translate('specs')),
      (_DetailsTab.reviews, context.translate('customer_reviews')),
      (_DetailsTab.seller, context.translate('seller_store')),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final tab = tabs[index].$1;
          final label = tabs[index].$2;
          final selected = tab == _selectedTab;
          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            label: Text(label),
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              color: selected ? Colors.white : Theme.of(context).hintColor,
              fontWeight: FontWeight.w700,
            ),
            side: BorderSide(
              color: selected
                  ? AppColors.primary
                  : Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.24),
            ),
            onSelected: (_) => setState(() => _selectedTab = tab),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: tabs.length,
      ),
    );
  }

  Widget _buildSelectedSection(BuildContext context) {
    switch (_selectedTab) {
      case _DetailsTab.overview:
        return Column(
          key: const ValueKey('overview'),
          children: [
            AppSurfaceCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.translate('overview'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.product.description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.55,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.product.detailImageUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...widget.product.detailImageUrls.map(
                (url) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AppSmartImage(
                      url: url,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      case _DetailsTab.specs:
        final mainCategory =
            widget.product.parentCategory ?? widget.product.category;
        final subCategory =
            widget.product.subCategory ?? widget.product.category;
        return Column(
          key: const ValueKey('specs'),
          children: [
            AppSurfaceCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (widget.product.brand != null &&
                      widget.product.brand!.trim().isNotEmpty)
                    _SpecRow(
                      label: context.translate('brand'),
                      value: widget.product.brand!,
                    ),
                  _SpecRow(
                    label: context.translate('main_category'),
                    value: AppConstants.getCategoryDisplay(
                      context,
                      mainCategory,
                    ),
                  ),
                  _SpecRow(
                    label: context.translate('sub_category'),
                    value: AppConstants.getCategoryDisplay(
                      context,
                      subCategory,
                    ),
                  ),
                  _SpecRow(
                    label: context.translate('stock'),
                    value: '${widget.product.stock}',
                  ),
                  _SpecRow(
                    label: context.translate('rating'),
                    value: widget.product.rating.toStringAsFixed(1),
                  ),
                  _SpecRow(
                    label: context.translate('reviews'),
                    value: '$_reviewCount',
                  ),
                ],
              ),
            ),
            if (widget.product.availableColors.isNotEmpty ||
                widget.product.availableSizes.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildOptionsSection(Theme.of(context)),
            ],
          ],
        );
      case _DetailsTab.reviews:
        return Column(
          key: const ValueKey('reviews'),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _reviewCount == 0
                        ? context.translate('no_reviews_yet')
                        : '${context.translate('based_on')} $_reviewCount ${_reviewCount == 1 ? context.translate('customer_review_count') : context.translate('customer_review_count_plural')}.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (_canReview)
                  TextButton.icon(
                    onPressed: _showAddReviewPage,
                    icon: const Icon(AppIcons.review, size: 18),
                    label: Text(context.translate('write_review')),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoadingReviews)
              const Center(child: CircularProgressIndicator())
            else if (_reviews.isEmpty)
              AppSurfaceCard(
                padding: const EdgeInsets.all(22),
                child: Text(context.translate('first_review_prompt')),
              )
            else
              ..._reviews.map(_buildReviewCard),
          ],
        );
      case _DetailsTab.seller:
        return Column(
          key: const ValueKey('seller'),
          children: [_buildSellerCard(context)],
        );
    }
  }

  Widget _buildGallery(ThemeData theme) {
    final images = _galleryImages;
    return Column(
      children: [
        AppSurfaceCard(
          padding: const EdgeInsets.all(0),
          radius: 30,
          child: Stack(
            children: [
              Hero(
                tag: 'product_${widget.product.id}',
                child: CarouselSlider(
                  options: CarouselOptions(
                    height: 360,
                    viewportFraction: 1,
                    enlargeCenterPage: false,
                    onPageChanged: (index, _) {
                      setState(() {
                        _currentImageIndex = index;
                      });
                    },
                  ),
                  items: images.map((url) {
                    return Padding(
                      padding: const EdgeInsets.all(22),
                      child: AppSmartImage(
                        url: url,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (widget.product.discountPrice != null)
                PositionedDirectional(
                  top: 18,
                  start: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${widget.product.discountPercentage.toStringAsFixed(0)}% ${context.translate('off')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final isSelected = _currentImageIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentImageIndex = index;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 78,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : theme.colorScheme.outline.withValues(alpha: 0.18),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AppSmartImage(
                        url: images[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemCount: images.length,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSellerStoreBanner(BuildContext context) {
    final storeName = _getStoreDisplayName(context);
    final storeDescription = _getStoreDescription(context);
    final cover = widget.product.images.isNotEmpty
        ? widget.product.images.first
        : widget.product.imageUrl;
    final logo = _seller?.storeLogo ?? _seller?.profileImageUrl;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VendorStorePage(
              vendorName: storeName,
              vendorId: widget.product.sellerId,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            SizedBox(
              height: 112,
              width: double.infinity,
              child: AppSmartImage(url: cover, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.74),
                      Colors.black.withValues(alpha: 0.34),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    backgroundImage: logo != null ? NetworkImage(logo) : null,
                    child: logo == null
                        ? const Icon(AppIcons.store, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          storeDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.34),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          AppIcons.store,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.translate('view_store'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerCard(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = _getStoreDisplayName(context);
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VendorStorePage(
              vendorName: displayName,
              vendorId: widget.product.sellerId,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              backgroundImage: _seller?.profileImageUrl != null
                  ? NetworkImage(_seller!.profileImageUrl!)
                  : null,
              child: _seller?.profileImageUrl == null
                  ? const Icon(AppIcons.store, color: AppColors.primary)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getStoreDescription(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? AppIcons.caretLeft
                  : AppIcons.caretRight,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsSection(ThemeData theme) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.translate('available_options'),
            style: theme.textTheme.titleLarge,
          ),
          if (widget.product.availableColors.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              context.translate('colors'),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: widget.product.availableColors.map((color) {
                return _OptionChip(label: color);
              }).toList(),
            ),
          ],
          if (widget.product.availableSizes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(context.translate('sizes'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: widget.product.availableSizes.map((size) {
                return _OptionChip(label: size);
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  backgroundImage: review.userImageUrl.isNotEmpty
                      ? NetworkImage(review.userImageUrl)
                      : null,
                  child: review.userImageUrl.isEmpty
                      ? Text(
                          review.userName.isNotEmpty
                              ? review.userName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy').format(review.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (review.isVerifiedPurchase) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            context.translate('verified_purchase'),
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(AppIcons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(review.rating.toStringAsFixed(1)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              review.comment.isEmpty
                  ? context.translate('no_written_comment')
                  : review.comment,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shouldStack = constraints.maxWidth < 340;
            final addToCart = shouldStack
                ? SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: widget.product.stock > 0
                          ? () {
                              _trackProductEvent('cart');
                              context.read<CartBloc>().add(
                                AddToCart(widget.product),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${widget.product.name} ${context.translate('added_to_cart')}',
                                  ),
                                ),
                              );
                            }
                          : null,
                      child: Text(
                        widget.product.stock > 0
                            ? context.translate('add_to_cart')
                            : context.translate('out_of_stock'),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.product.stock > 0
                              ? AppColors.primary
                              : Colors.grey,
                        ),
                      ),
                    ),
                  )
                : Expanded(
                    child: OutlinedButton(
                      onPressed: widget.product.stock > 0
                          ? () {
                              _trackProductEvent('cart');
                              context.read<CartBloc>().add(
                                AddToCart(widget.product),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${widget.product.name} ${context.translate('added_to_cart')}',
                                  ),
                                ),
                              );
                            }
                          : null,
                      child: Text(
                        widget.product.stock > 0
                            ? context.translate('add_to_cart')
                            : context.translate('out_of_stock'),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.product.stock > 0
                              ? AppColors.primary
                              : Colors.grey,
                        ),
                      ),
                    ),
                  );

            final buyNow = shouldStack
                ? SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.product.stock > 0
                          ? () {
                              _trackProductEvent('click');
                              context.read<CartBloc>().add(
                                AddToCart(widget.product),
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CheckoutPage(),
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.product.stock > 0
                            ? AppColors.primary
                            : Colors.grey,
                      ),
                      child: Text(
                        context.translate('buy_now'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                : Expanded(
                    child: ElevatedButton(
                      onPressed: widget.product.stock > 0
                          ? () {
                              _trackProductEvent('click');
                              context.read<CartBloc>().add(
                                AddToCart(widget.product),
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CheckoutPage(),
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.product.stock > 0
                            ? AppColors.primary
                            : Colors.grey,
                      ),
                      child: Text(
                        context.translate('buy_now'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );

            if (shouldStack) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [addToCart, const SizedBox(height: 10), buyNow],
              );
            }

            return Row(
              children: [addToCart, const SizedBox(width: 16), buyNow],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSimilarProductsSection(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<Product>>(
      future: _similarProductsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 230,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final products = snapshot.data ?? const <Product>[];
        if (products.isEmpty) {
          return const SizedBox.shrink();
        }

        return AppSurfaceCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.translate('similar_products'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 254,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return SizedBox(
                      width: 176,
                      child: ProductCard(
                        product: product,
                        onTap: () {
                          Navigator.pushReplacement(
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
        );
      },
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.icon, required this.label, this.accentColor});

  final IconData icon;
  final String label;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accentColor ?? AppColors.primary),
          const SizedBox(width: 8),
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

class _OptionChip extends StatelessWidget {
  const _OptionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

enum _DetailsTab { overview, specs, reviews, seller }

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
