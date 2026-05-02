import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:untitled1/core/constants/app_constants.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/localization/localized_error_message.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_empty_state.dart';
import 'package:untitled1/core/widgets/app_page_intro_card.dart';
import 'package:untitled1/core/widgets/app_section_header.dart';
import 'package:untitled1/core/widgets/product_card.dart';
import 'package:untitled1/features/product/presentation/bloc/product_bloc.dart';
import 'package:untitled1/features/product/presentation/bloc/product_event.dart';
import 'package:untitled1/features/product/presentation/bloc/product_state.dart';
import 'package:untitled1/features/product/domain/entities/product.dart';
import 'package:untitled1/features/product/domain/repositories/product_repository.dart';
import 'package:untitled1/features/cart/presentation/pages/cart_page.dart';
import 'package:untitled1/injection_container.dart';
import 'package:untitled1/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:untitled1/features/cart/presentation/bloc/cart_state.dart';
import 'package:untitled1/features/notifications/presentation/pages/notifications_page.dart';
import 'package:untitled1/features/search/presentation/pages/search_page.dart';
import 'package:untitled1/features/profile/presentation/pages/contact_support_page.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../admin/presentation/pages/admin_panel_page.dart';
import '../../../checkout/presentation/pages/my_orders_page.dart';
import '../../../product/presentation/pages/categories_page.dart';
import '../../../product/presentation/pages/wishlist_page.dart';
import '../../../product/presentation/pages/product_details_page.dart';
import '../../../vendor/presentation/pages/vendor_store_page.dart';
import '../../../../features/profile/presentation/pages/store_setup_page.dart';

void _openProductDetails(BuildContext context, Product product) {
  final authState = context.read<AuthBloc>().state;
  final viewerId = authState is Authenticated ? authState.user.id : null;
  sl<ProductRepository>()
      .trackProductEvent(
        productId: product.id,
        eventType: 'click',
        viewerId: viewerId,
      )
      .catchError((_) {});
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is Authenticated &&
          authState.user.isSeller &&
          !authState.user.isBanned) {
        final user = authState.user;
        // If storeName is null or is the default name, or no description, show setup.
        // Also check profileImageUrl to see if they uploaded a logo.
        final needsSetup =
            user.storeDescription == null ||
            user.storeDescription!.isEmpty ||
            user.storeName == null ||
            user.storeName == '${user.name} Store';

        if (needsSetup) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StoreSetupPage()),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return BlocProvider(
      create: (context) => sl<ProductBloc>()..add(const FetchProducts()),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        drawer: _buildDrawer(context),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                isDark ? AppColors.darkBackground : const Color(0xFFF7F8FA),
                isDark ? AppColors.darkSurfaceAlt : const Color(0xFFF1F3F8),
                theme.scaffoldBackgroundColor,
              ],
            ),
          ),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                pinned: true,
                backgroundColor: theme.colorScheme.surface.withValues(
                  alpha: isDark ? 0.88 : 0.94,
                ),
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                expandedHeight: 146,
                toolbarHeight: 66,
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: FlexibleSpaceBar(
                      background: Container(
                        color: theme.colorScheme.surface.withValues(
                          alpha: isDark ? 0.78 : 0.9,
                        ),
                      ),
                    ),
                  ),
                ),
                titleSpacing: 8,
                title: Text(
                  context.translate('explore'),
                  style: theme.textTheme.titleLarge,
                ),
                actions: [
                  _CircleGlassAction(
                    icon: AppIcons.notifications,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsPage(),
                      ),
                    ),
                  ),
                  _CartAction(),
                  const SizedBox(width: 8),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(64),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _buildSearchTrigger(context),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const _BannerSlider()
                        .animate()
                        .fadeIn(duration: 800.ms)
                        .moveY(begin: 30, end: 0),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                      child: AppPageIntroCard(
                        title: context.translate('welcome_sahla_market'),
                        subtitle: context.translate('home_hub_subtitle'),
                        trailing: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            AppIcons.sparkles,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const _CategorySection().animate().fadeIn(delay: 200.ms),
                    const _FlashDealsSection().animate().fadeIn(delay: 400.ms),
                    const _FeaturedProductsSection().animate().fadeIn(
                      delay: 600.ms,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.84,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(6, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildDrawerHeader(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  children: [
                    _DrawerMenuTile(
                      icon: AppIcons.home,
                      label: context.translate('home'),
                      onTap: () => Navigator.pop(context),
                    ),
                    _DrawerMenuTile(
                      icon: AppIcons.categories,
                      label: context.translate('categories'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CategoriesPage(),
                          ),
                        );
                      },
                    ),
                    _DrawerMenuTile(
                      icon: AppIcons.orders,
                      label: context.translate('orders'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyOrdersPage(),
                          ),
                        );
                      },
                    ),
                    _DrawerMenuTile(
                      icon: AppIcons.wishlist,
                      label: context.translate('wishlist'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WishlistPage(),
                          ),
                        );
                      },
                    ),
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        if (state is Authenticated && state.user.isAdmin) {
                          return _DrawerMenuTile(
                            icon: AppIcons.settings,
                            label: context.translate('admin_panel'),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AdminPanelPage(),
                                ),
                              );
                            },
                          );
                        }
                        if (state is Authenticated && state.user.isSeller) {
                          return _DrawerMenuTile(
                            icon: AppIcons.store,
                            label: context.translate('my_store'),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VendorStorePage(
                                    vendorName:
                                        state.user.storeName ?? state.user.name,
                                  ),
                                ),
                              );
                            },
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                child: Column(
                  children: [
                    _DrawerMenuTile(
                      icon: AppIcons.help,
                      label: context.translate('help_support'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContactSupportPage(),
                          ),
                        );
                      },
                    ),
                    _DrawerMenuTile(
                      icon: AppIcons.logout,
                      label: context.translate('logout'),
                      danger: true,
                      onTap: () {
                        Navigator.pop(context);
                        context.read<AuthBloc>().add(LogoutRequested());
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        String name = context.translate('sahla_user');
        String email = context.translate('welcome_sahla_market');
        String? photoUrl;

        if (state is Authenticated) {
          name = state.user.name;
          email = state.user.email;
          photoUrl = state.user.profileImageUrl;
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                backgroundImage: photoUrl != null
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null
                    ? const Icon(
                        AppIcons.profile,
                        size: 34,
                        color: AppColors.primary,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.84),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchTrigger(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SearchPage()),
      ),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.search,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              context.translate('search_hint'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleGlassAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _CircleGlassAction({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: theme.colorScheme.onSurface, size: 22),
        onPressed: onPressed,
      ),
    );
  }
}

class _CartAction extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _CircleGlassAction(
          icon: AppIcons.cart,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CartPage()),
          ),
        ),
        PositionedDirectional(
          end: 4,
          top: 4,
          child: BlocBuilder<CartBloc, CartState>(
            builder: (context, state) {
              if (state.items.isEmpty) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  '${state.items.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ).animate().scale();
            },
          ),
        ),
      ],
    );
  }
}

class _DrawerMenuTile extends StatelessWidget {
  const _DrawerMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = danger ? Colors.redAccent : AppColors.primary;
    final textColor = danger ? Colors.redAccent : theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.22,
        ),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  AppIcons.caretRight,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerSlider extends StatefulWidget {
  const _BannerSlider();
  @override
  State<_BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<_BannerSlider> {
  int _current = 0;

  List<Map<String, dynamic>> getBannerData(BuildContext context) {
    return [
      {
        'image': 'assets/images/bannerwsl.png',
        'isAsset': true,
        'showOverlay': false,
      },

      {
        'image': 'assets/images/bannerfashion1.png',
        'isAsset': true,
        'showOverlay': false,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bannerData = getBannerData(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 190,
            viewportFraction: 0.92,
            enlargeCenterPage: true,
            enlargeStrategy: CenterPageEnlargeStrategy.zoom,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 5),
            onPageChanged: (index, _) => setState(() => _current = index),
          ),
          items: bannerData.map((data) {
            final isAsset = data['isAsset'] as bool? ?? false;
            final showOverlay = data['showOverlay'] as bool? ?? true;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: isAsset
                          ? Image.asset(
                              data['image'] as String,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              data['image'] as String,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: const Icon(AppIcons.warning),
                                  ),
                            ),
                    ),
                    if (showOverlay)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                              colors: [
                                Colors.black.withValues(alpha: 0.85),
                                Colors.black.withValues(alpha: 0.3),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (data['title'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      data['title'] as String,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                if (data['subtitle'] != null)
                                  Text(
                                    data['subtitle'] as String,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      height: 1.1,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: bannerData.asMap().entries.map((entry) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _current == entry.key ? 24 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _current == entry.key
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.2),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection();
  @override
  Widget build(BuildContext context) {
    final categories = [
      {'name': 'Phones', 'icon': AppIcons.categoryPhones},
      {'name': 'Laptops', 'icon': AppIcons.categoryLaptops},
      {'name': 'Fashion', 'icon': AppIcons.categoryFashion},
      {'name': 'Home', 'icon': AppIcons.categoryHome},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: context.translate('categories'),
          subtitle: context.translate('categories_subtitle'),
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
        ),
        SizedBox(
          height: 108,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final theme = Theme.of(context);
              final categoryName = categories[index]['name'] as String;
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 20),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CategoriesPage(initialCategory: categoryName),
                          ),
                        );
                      },
                      child: Container(
                        height: 64,
                        width: 64,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.18,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          categories[index]['icon'] as IconData,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppConstants.getCategoryDisplay(context, categoryName),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FlashDealsSection extends StatelessWidget {
  const _FlashDealsSection();
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductBloc, ProductState>(
      builder: (context, state) {
        if (state is ProductLoaded) {
          final flashDeals = state.products
              .where((p) => p.isFlashDeal)
              .toList();
          if (flashDeals.isEmpty) return const SizedBox.shrink();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: AppSectionHeader(
                        title: context.translate('flash_deals'),
                        subtitle: context.translate('flash_deals_subtitle'),
                      ),
                    ),
                    const Icon(AppIcons.offer, color: AppColors.accent),
                  ],
                ),
              ),
              SizedBox(
                height: 240,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: flashDeals.length,
                  itemBuilder: (context, index) => Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 15),
                    child: ProductCard(
                      product: flashDeals[index],
                      onTap: () =>
                          _openProductDetails(context, flashDeals[index]),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _FeaturedProductsSection extends StatefulWidget {
  const _FeaturedProductsSection();

  @override
  State<_FeaturedProductsSection> createState() =>
      _FeaturedProductsSectionState();
}

enum _HomeFeaturedSort { recommended, newest, priceLowHigh, ratingHigh }

class _FeaturedProductsSectionState extends State<_FeaturedProductsSection> {
  _HomeFeaturedSort _sort = _HomeFeaturedSort.recommended;

  List<Product> _sortProducts(List<Product> products) {
    final sorted = [...products];
    switch (_sort) {
      case _HomeFeaturedSort.recommended:
        sorted.sort((a, b) {
          final scoreB =
              (b.rating * 10) + b.reviewsCount + (b.isFlashDeal ? 5 : 0);
          final scoreA =
              (a.rating * 10) + a.reviewsCount + (a.isFlashDeal ? 5 : 0);
          return scoreB.compareTo(scoreA);
        });
      case _HomeFeaturedSort.newest:
        sorted.sort((a, b) => b.id.compareTo(a.id));
      case _HomeFeaturedSort.priceLowHigh:
        sorted.sort(
          (a, b) => (a.discountPrice ?? a.price).compareTo(
            b.discountPrice ?? b.price,
          ),
        );
      case _HomeFeaturedSort.ratingHigh:
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductBloc, ProductState>(
      builder: (context, state) {
        if (state is ProductError) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: AppEmptyState(
              icon: AppIcons.warning,
              title: context.translate('products_unavailable'),
              subtitle: localizeErrorMessage(context, state.message),
              accentColor: Colors.redAccent,
            ),
          );
        }

        if (state is ProductLoaded) {
          final featuredProducts = _sortProducts(state.products);
          if (featuredProducts.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: AppEmptyState(
                icon: AppIcons.bagOpen,
                title: context.translate('no_products_found'),
                subtitle: context.translate('featured_products_subtitle'),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionHeader(
                title: context.translate('featured_products'),
                subtitle: context.translate('featured_products_subtitle'),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: PopupMenuButton<_HomeFeaturedSort>(
                  initialValue: _sort,
                  onSelected: (value) => setState(() => _sort = value),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _HomeFeaturedSort.recommended,
                      child: Text(context.translate('sort_relevance')),
                    ),
                    PopupMenuItem(
                      value: _HomeFeaturedSort.newest,
                      child: Text(context.translate('sort_newest')),
                    ),
                    PopupMenuItem(
                      value: _HomeFeaturedSort.priceLowHigh,
                      child: Text(context.translate('sort_price_low_high')),
                    ),
                    PopupMenuItem(
                      value: _HomeFeaturedSort.ratingHigh,
                      child: Text(context.translate('sort_rating_high')),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(AppIcons.filter, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          context.translate('sort_label'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 15),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                ),
                itemCount: featuredProducts.length,
                itemBuilder: (context, index) => ProductCard(
                  product: featuredProducts[index],
                  onTap: () =>
                      _openProductDetails(context, featuredProducts[index]),
                ),
              ),
              const SizedBox(height: 30),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
