import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/localization/localized_error_message.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_empty_state.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:untitled1/core/widgets/app_page_intro_card.dart';
import 'package:untitled1/core/widgets/app_section_header.dart';
import 'package:untitled1/core/widgets/app_smart_image.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/core/widgets/product_card.dart';
import 'package:untitled1/features/product/presentation/pages/product_details_page.dart';
import 'package:untitled1/features/product/domain/repositories/product_repository.dart';
import 'package:untitled1/features/chat/presentation/pages/chat_page.dart';
import 'package:untitled1/features/vendor/domain/entities/vendor_store_view.dart';
import 'package:untitled1/features/vendor/presentation/cubit/vendor_store_cubit.dart';
import 'package:untitled1/features/vendor/presentation/cubit/vendor_store_state.dart';
import 'package:untitled1/features/vendor/presentation/pages/add_product_page.dart';
import 'package:untitled1/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:untitled1/features/vendor/presentation/pages/vendor_orders_page.dart';
import 'package:untitled1/features/vendor/presentation/widgets/earnings_card.dart';
import 'package:untitled1/injection_container.dart';

class VendorStorePage extends StatefulWidget {
  const VendorStorePage({super.key, required this.vendorName, this.vendorId});

  final String vendorName;
  final String? vendorId;

  @override
  State<VendorStorePage> createState() => _VendorStorePageState();
}

class _VendorStorePageState extends State<VendorStorePage> {
  late final String? _currentUserId;
  late final String? _effectiveVendorId;
  late final bool _isViewingOwnStore;
  late final VendorStoreCubit _vendorStoreCubit;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentUserId = SupabaseService.currentUserId;
    _effectiveVendorId = widget.vendorId ?? _currentUserId;
    _isViewingOwnStore =
        _effectiveVendorId != null && _effectiveVendorId == _currentUserId;
    _vendorStoreCubit = sl<VendorStoreCubit>();
    final effectiveVendorId = _effectiveVendorId;
    if (effectiveVendorId != null) {
      _vendorStoreCubit.loadStore(
        vendorId: effectiveVendorId,
        fallbackStoreName: widget.vendorName,
        includeInsights: _isViewingOwnStore,
        currentUserId: _currentUserId,
      );
    }
  }

  @override
  void dispose() {
    _vendorStoreCubit.close();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadStoreImage(bool isBanner) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (!mounted || image == null) {
      return;
    }

    await _vendorStoreCubit.uploadStoreImage(
      imageFile: File(image.path),
      isBanner: isBanner,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_effectiveVendorId == null) {
      return AppGradientScaffold(
        body: AppEmptyState(
          icon: AppIcons.store,
          title: context.translate('store_not_found'),
          subtitle: context.translate('store_not_found_msg'),
        ),
      );
    }

    return BlocProvider.value(
      value: _vendorStoreCubit,
      child: BlocConsumer<VendorStoreCubit, VendorStoreState>(
        listener: (context, state) {
          if (state.actionErrorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  localizeErrorMessage(context, state.actionErrorMessage),
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        builder: (context, state) {
          final view = state.view;
          final canPublishProducts =
              _isViewingOwnStore && (view?.isSellerApproved ?? false);

          return AppGradientScaffold(
            floatingActionButton: canPublishProducts
                ? FloatingActionButton.extended(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddProductPage(),
                        ),
                      );
                    },
                    backgroundColor: AppColors.primary,
                    icon: const Icon(AppIcons.plus, color: Colors.white),
                    label: Text(
                      context.translate('add_product'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ).animate().scale(delay: 400.ms)
                : null,
            body: _buildBody(context, state, view),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    VendorStoreState state,
    VendorStoreView? view,
  ) {
    if (state.isLoading && view == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && view == null) {
      return AppEmptyState(
        icon: AppIcons.warning,
        title: context.translate('store_unavailable'),
        subtitle: localizeErrorMessage(context, state.errorMessage),
        accentColor: Colors.redAccent,
      );
    }

    if (view == null) {
      return AppEmptyState(
        icon: AppIcons.store,
        title: context.translate('store_unavailable'),
        subtitle: context.translate('store_load_error'),
      );
    }

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              backgroundColor: AppColors.primary,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppSmartImage(
                      url:
                          view.coverImageUrl ??
                          'https://images.unsplash.com/photo-1497215728101-856f4ea42174?w=800&q=80',
                      fit: BoxFit.cover,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.12),
                            Colors.black.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                    ),
                    if (_isViewingOwnStore)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: SafeArea(
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            radius: 18,
                            child: IconButton(
                              icon: const Icon(
                                AppIcons.camera,
                                size: 18,
                                color: Colors.white,
                              ),
                              onPressed: state.isSaving
                                  ? null
                                  : () => _pickAndUploadStoreImage(true),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 20,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 12,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 44,
                                  backgroundColor: Colors.white,
                                  child: ClipOval(
                                    child: SizedBox(
                                      width: 88,
                                      height: 88,
                                      child: view.storeLogoUrl == null
                                          ? const Icon(
                                              AppIcons.store,
                                              size: 40,
                                              color: AppColors.primary,
                                            )
                                          : AppSmartImage(
                                              url: view.storeLogoUrl!,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_isViewingOwnStore)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.primary,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                        AppIcons.edit,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      onPressed: state.isSaving
                                          ? null
                                          : () =>
                                                _pickAndUploadStoreImage(false),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    view.storeName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (view.isVerifiedSeller) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.16,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.34,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.verified_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            context.translate(
                                              'verified_seller',
                                            ),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    _isViewingOwnStore
                                        ? context.translate('manage_storefront')
                                        : context.translate(
                                            'browse_seller_products',
                                          ),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (!_isViewingOwnStore &&
                                      _currentUserId != null &&
                                      _effectiveVendorId != null) ...[
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ChatPage(
                                                  currentUserId: _currentUserId,
                                                  otherUserId:
                                                      _effectiveVendorId,
                                                  otherUserName: view.storeName,
                                                ),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white
                                                .withValues(alpha: 0.15),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              side: BorderSide(
                                                color: Colors.white.withValues(
                                                  alpha: 0.3,
                                                ),
                                              ),
                                            ),
                                          ),
                                          icon: const Icon(
                                            AppIcons.messages,
                                            size: 16,
                                          ),
                                          label: Text(
                                            context.translate('message'),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _vendorStoreCubit.toggleFollow(),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: view.isFollowing
                                                ? Colors.white.withValues(
                                                    alpha: 0.3,
                                                  )
                                                : Colors.white,
                                            foregroundColor: view.isFollowing
                                                ? Colors.white
                                                : AppColors.primary,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          icon: Icon(
                                            view.isFollowing
                                                ? Icons.check
                                                : AppIcons.plus,
                                            size: 16,
                                          ),
                                          label: Text(
                                            view.isFollowing
                                                ? context.translate('following')
                                                : context.translate('follow'),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  children: [
                    if (_isViewingOwnStore)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const VendorOrdersPage(),
                            ),
                          );
                        },
                        child: EarningsCard(
                          totalEarnings: view.totalEarnings,
                          pendingOrders: view.pendingOrders,
                          completedOrders: view.completedOrders,
                          weeklyViews: view.weeklyViews,
                          weeklyClicks: view.weeklyClicks,
                          weeklySalesCount: view.weeklySalesCount,
                          topProductName: view.topProductName,
                          ctr: view.ctr,
                          clickToCartRate: view.clickToCartRate,
                          cartToPurchaseRate: view.cartToPurchaseRate,
                          overallPurchaseRate: view.overallPurchaseRate,
                          lowStockCount: view.lowStockCount,
                        ),
                      ),
                    if (_isViewingOwnStore) const SizedBox(height: 20),
                    if (_isViewingOwnStore && !view.isSellerApproved) ...[
                      AppSurfaceCard(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.translate(
                                      'seller_approval_pending',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    context.translate(
                                      'seller_approval_pending_msg',
                                    ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    AppSurfaceCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppPageIntroCard(
                            title: view.storeName,
                            subtitle: view.storeDescription,
                            trailing: _isViewingOwnStore
                                ? IconButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const EditProfilePage(),
                                        ),
                                      ).then((_) {
                                        if (_effectiveVendorId == null) {
                                          return;
                                        }
                                        _vendorStoreCubit.loadStore(
                                          vendorId: _effectiveVendorId,
                                          fallbackStoreName: widget.vendorName,
                                          includeInsights: _isViewingOwnStore,
                                          currentUserId: _currentUserId,
                                        );
                                      });
                                    },
                                    icon: const Icon(
                                      AppIcons.edit,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 14),
                          _buildStoreHighlights(context, view),
                          const SizedBox(height: 20),
                          _buildStatsWrap(context, view),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: AppSurfaceCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.trim().toLowerCase();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: context.translate('search_in_store'),
                            prefixIcon: const Icon(AppIcons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(AppIcons.close, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppSectionHeader(
                        title: _isViewingOwnStore
                            ? context.translate('my_products')
                            : context.translate('store_products'),
                        subtitle: '',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (view.products.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: AppEmptyState(
                    icon: AppIcons.bagOpen,
                    title: context.translate('no_products_yet'),
                    subtitle: context.translate('no_products_yet_msg'),
                  ),
                ),
              )
            else
              Builder(
                builder: (context) {
                  final filteredProducts = view.products.where((product) {
                    if (_searchQuery.isEmpty) return true;
                    return product.name.toLowerCase().contains(_searchQuery) ||
                        product.description.toLowerCase().contains(
                          _searchQuery,
                        );
                  }).toList();

                  if (filteredProducts.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        child: AppEmptyState(
                          icon: AppIcons.search,
                          title: context.translate('no_results_found'),
                          subtitle: context.translate('search_no_results_msg'),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.68,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final product = filteredProducts[index];
                        return Stack(
                          children: [
                            ProductCard(
                              product: product,
                              onTap: () {
                                sl<ProductRepository>()
                                    .trackProductEvent(
                                      productId: product.id,
                                      eventType: 'click',
                                      viewerId: _currentUserId,
                                    )
                                    .catchError((_) {});
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProductDetailsPage(product: product),
                                  ),
                                );
                              },
                            ),
                            if (_isViewingOwnStore)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: IconButton(
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(AppIcons.edit, size: 18),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AddProductPage(
                                          productToEdit: product,
                                        ),
                                      ),
                                    ).then((_) {
                                      if (_effectiveVendorId == null) {
                                        return;
                                      }
                                      _vendorStoreCubit.loadStore(
                                        vendorId: _effectiveVendorId,
                                        fallbackStoreName: widget.vendorName,
                                        includeInsights: _isViewingOwnStore,
                                        currentUserId: _currentUserId,
                                      );
                                    });
                                  },
                                ),
                              ),
                          ],
                        );
                      }, childCount: filteredProducts.length),
                    ),
                  );
                },
              ),
          ],
        ),
        if (state.isSaving)
          Container(
            color: Colors.black45,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildStoreHighlights(BuildContext context, VendorStoreView view) {
    List<MapEntry<String, int>>? topCategory;
    if (view.products.isNotEmpty) {
      topCategory = view.products
          .map((product) => product.parentCategory ?? product.category)
          .fold<Map<String, int>>({}, (acc, category) {
            acc[category] = (acc[category] ?? 0) + 1;
            return acc;
          })
          .entries
          .toList();
      topCategory.sort((a, b) => b.value.compareTo(a.value));
    }

    final bestCategory = topCategory == null || topCategory.isEmpty
        ? null
        : topCategory.first.key;

    Widget chip(IconData icon, String label, String value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              '$label: $value',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(
          AppIcons.bagOpen,
          context.translate('products'),
          '${view.products.length}',
        ),
        chip(
          Icons.people_outline,
          context.translate('followers'),
          '${view.followerCount}',
        ),
        if (bestCategory != null)
          chip(
            AppIcons.categories,
            context.translate('top_category'),
            bestCategory,
          ),
        if (view.isVerifiedSeller)
          chip(
            Icons.verified_rounded,
            context.translate('trust_badge'),
            context.translate('verified_seller'),
          ),
      ],
    );
  }

  Widget _buildStatsWrap(BuildContext context, VendorStoreView view) {
    final items = <_StoreStat>[
      _StoreStat(
        label: context.translate('products'),
        value: '${view.products.length}',
        icon: AppIcons.bagOpen,
      ),
      _StoreStat(
        label: context.translate('followers'),
        value: '${view.followerCount}',
        icon: Icons.people_outline,
      ),
      if (_isViewingOwnStore) ...[
        _StoreStat(
          label: context.translate('pending'),
          value: '${view.pendingOrders}',
          icon: AppIcons.orders,
        ),
        _StoreStat(
          label: context.translate('completed'),
          value: '${view.completedOrders}',
          icon: AppIcons.check,
        ),
      ] else
        _StoreStat(
          label: context.translate('categories'),
          value:
              '${view.products.map((product) => product.category).toSet().length}',
          icon: AppIcons.categories,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map((item) => SizedBox(width: itemWidth, child: item))
              .toList(),
        );
      },
    );
  }
}

class _StoreStat extends StatelessWidget {
  const _StoreStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
