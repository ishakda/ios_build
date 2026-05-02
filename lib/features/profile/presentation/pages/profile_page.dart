import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/theme/theme_bloc.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_event.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_state.dart';
import 'package:untitled1/features/checkout/presentation/bloc/order_bloc.dart';
import 'package:untitled1/features/checkout/presentation/bloc/order_event.dart';
import 'package:untitled1/features/checkout/presentation/bloc/order_state.dart';
import 'package:untitled1/features/product/presentation/pages/wishlist_page.dart';
import 'package:untitled1/features/product/presentation/pages/recently_viewed_page.dart';
import 'package:untitled1/features/checkout/presentation/pages/my_orders_page.dart';
import 'package:untitled1/features/admin/presentation/pages/admin_panel_page.dart';
import 'package:untitled1/features/profile/presentation/pages/about_us_page.dart';
import 'package:untitled1/features/profile/presentation/pages/contact_support_page.dart';
import 'package:untitled1/features/profile/presentation/pages/address_management_page.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/localization/language_bloc.dart';
import 'package:untitled1/features/profile/presentation/pages/payment_methods_page.dart';

import 'package:untitled1/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:untitled1/features/profile/presentation/pages/settings_page.dart';

import 'package:untitled1/features/vendor/presentation/pages/vendor_store_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isDark ? const Color(0xFF0C1018) : const Color(0xFFF9F7F1),
            isDark ? const Color(0xFF111827) : const Color(0xFFF1F5FC),
            theme.scaffoldBackgroundColor,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const _ProfileBackdrop(),
            SafeArea(
              child: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, authState) {
                  final user = authState is Authenticated
                      ? authState.user
                      : null;
                  final shortcuts = _buildShortcuts(context, user);

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ProfileTopBar(
                                onShowLanguageDialog: () =>
                                    _showLanguageDialog(context),
                              ),
                              const SizedBox(height: 20),
                              _ProfileHeroCard(user: user)
                                  .animate()
                                  .fadeIn(duration: 400.ms)
                                  .slideY(begin: 0.08, end: 0),
                              const SizedBox(height: 24),
                              _SectionIntro(
                                title: context.translate('quick_access_title'),
                                subtitle: context.translate(
                                  'quick_access_subtitle',
                                ),
                              ),
                              const SizedBox(height: 14),
                              _ShortcutGrid(items: shortcuts)
                                  .animate()
                                  .fadeIn(delay: 120.ms, duration: 420.ms)
                                  .slideY(begin: 0.08, end: 0),
                              const SizedBox(height: 24),
                              const _OrderStats()
                                  .animate()
                                  .fadeIn(delay: 180.ms, duration: 420.ms)
                                  .slideY(begin: 0.08, end: 0),
                              const SizedBox(height: 24),
                              _AccountSection(user: user)
                                  .animate()
                                  .fadeIn(delay: 240.ms, duration: 420.ms)
                                  .slideY(begin: 0.08, end: 0),
                              const SizedBox(height: 20),
                              const _SupportSection()
                                  .animate()
                                  .fadeIn(delay: 300.ms, duration: 420.ms)
                                  .slideY(begin: 0.08, end: 0),
                              if (authState is Authenticated) ...[
                                const SizedBox(height: 20),
                                _LogoutCard(
                                      onLogout: () =>
                                          _showLogoutDialog(context),
                                    )
                                    .animate()
                                    .fadeIn(delay: 360.ms, duration: 420.ms)
                                    .slideY(begin: 0.08, end: 0),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_ShortcutItem> _buildShortcuts(BuildContext context, User? user) {
    final items = <_ShortcutItem>[
      _ShortcutItem(
        title: context.translate('orders'),
        subtitle: context.translate('track_delivery_states'),
        icon: AppIcons.orders,
        color: AppColors.primary,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyOrdersPage()),
          );
        },
      ),
      _ShortcutItem(
        title: context.translate('wishlist'),
        subtitle: context.translate('saved_products'),
        icon: AppIcons.wishlistActive,
        color: const Color(0xFFE35D7B),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WishlistPage()),
          );
        },
      ),
      _ShortcutItem(
        title: context.translate('recently_viewed'),
        subtitle: context.translate('resume_browsing'),
        icon: AppIcons.history,
        color: const Color(0xFF8B5CF6),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RecentlyViewedPage()),
          );
        },
      ),
    ];

    if (user?.isAdmin == true) {
      items.insert(
        0,
        _ShortcutItem(
          title: context.translate('admin_panel'),
          subtitle: context.translate('moderation_tools'),
          icon: AppIcons.settings,
          color: const Color(0xFFEF4444),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminPanelPage()),
            );
          },
        ),
      );
    } else if (user?.role == 'seller') {
      items.insert(
        0,
        _ShortcutItem(
          title: context.translate('seller_dashboard'),
          subtitle: context.translate('store_performance'),
          icon: AppIcons.store,
          color: const Color(0xFF10B981),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VendorStorePage(
                  vendorName: user?.storeName ?? user?.name ?? '',
                ),
              ),
            );
          },
        ),
      );
    }

    return items;
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (diagContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.translate('language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LanguageOption(
              label: 'English',
              code: 'en',
              onSelected: () {
                context.read<LanguageBloc>().add(ChangeLanguage('en'));
                Navigator.pop(diagContext);
              },
            ),
            _LanguageOption(
              label: 'Arabic',
              code: 'ar',
              onSelected: () {
                context.read<LanguageBloc>().add(ChangeLanguage('ar'));
                Navigator.pop(diagContext);
              },
            ),
            _LanguageOption(
              label: 'French',
              code: 'fr',
              onSelected: () {
                context.read<LanguageBloc>().add(ChangeLanguage('fr'));
                Navigator.pop(diagContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (diagContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.translate('logout')),
        content: Text(context.translate('logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(diagContext),
            child: Text(context.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(diagContext);
              context.read<AuthBloc>().add(LogoutRequested());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(
              context.translate('logout'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileBackdrop extends StatelessWidget {
  const _ProfileBackdrop();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -60,
            child: _BackdropOrb(
              size: 240,
              color: (isDark ? AppColors.primaryLight : AppColors.accent)
                  .withValues(alpha: isDark ? 0.12 : 0.16),
            ),
          ),
          Positioned(
            top: 120,
            left: -70,
            child: _BackdropOrb(
              size: 210,
              color: AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.10),
            ),
          ),
          Positioned(
            bottom: 120,
            right: -80,
            child: _BackdropOrb(
              size: 220,
              color: const Color(
                0xFF14B8A6,
              ).withValues(alpha: isDark ? 0.10 : 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar({required this.onShowLanguageDialog});

  final VoidCallback onShowLanguageDialog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.translate('profile'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, state) {
            return _CircleActionButton(
              icon: state.themeMode == AppTheme.dark
                  ? AppIcons.sun
                  : AppIcons.moon,
              onPressed: () => context.read<ThemeBloc>().add(ToggleTheme()),
            );
          },
        ),
        _CircleActionButton(
          icon: AppIcons.language,
          onPressed: onShowLanguageDialog,
        ),
      ],
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusText = _buildStatusText(context, user);
    final chips = _buildChips(context);

    return AppSurfaceCard(
      radius: 30,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.14),
              AppColors.accent.withValues(alpha: 0.12),
              Colors.transparent,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileAvatar(user: user),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(
                              alpha: 0.78,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            user == null
                                ? context.translate('guest_workspace')
                                : context.translate('sahla_member'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user?.name ?? context.translate('welcome_guest'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          user?.email ?? context.translate('sign_in_sync'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          statusText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(spacing: 10, runSpacing: 10, children: chips),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfilePage(),
                      ),
                    );
                  },
                  icon: const Icon(AppIcons.edit, size: 18),
                  label: Text(context.translate('edit_profile')),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChips(BuildContext context) {
    if (user == null) {
      return [
        _StatusChip(
          label: context.translate('browse_mode'),
          icon: AppIcons.profile,
          color: AppColors.primary,
        ),
      ];
    }

    final chips = <Widget>[
      _StatusChip(
        label: user!.isAdmin
            ? context.translate('admin_access')
            : user!.isSeller
            ? context.translate('seller_account')
            : context.translate('buyer_account'),
        icon: user!.isAdmin
            ? AppIcons.settings
            : user!.isSeller
            ? AppIcons.store
            : AppIcons.buyer,
        color: user!.isAdmin
            ? const Color(0xFFEF4444)
            : user!.isSeller
            ? const Color(0xFF10B981)
            : AppColors.primary,
      ),
      _StatusChip(
        label: user!.isEmailVerified
            ? context.translate('email_verified_status')
            : context.translate('verify_email_status'),
        icon: user!.isEmailVerified ? AppIcons.check : AppIcons.warning,
        color: user!.isEmailVerified
            ? const Color(0xFF10B981)
            : const Color(0xFFF59E0B),
      ),
    ];

    if (user!.isSeller && user!.storeName != null) {
      chips.add(
        _StatusChip(
          label: user!.storeName!,
          icon: AppIcons.storeActive,
          color: const Color(0xFF8B5CF6),
        ),
      );
    }

    if (user!.isCodBlocked) {
      chips.add(
        _StatusChip(
          label: context.translate('cod_blocked'),
          icon: AppIcons.warning,
          color: Color(0xFFEF4444),
        ),
      );
    }

    return chips;
  }

  String _buildStatusText(BuildContext context, User? user) {
    if (user == null) {
      return context.translate('profile_sign_in_hint');
    }
    if (user.isBanned) {
      return user.banReason?.trim().isNotEmpty == true
          ? user.banReason!
          : 'Account suspended';
    }
    if (user.isSeller) {
      return user.canPublishProducts
          ? context.translate('profile_store_ready')
          : user.sellerPublishingBlocker ??
                context.translate('profile_store_setup_progress');
    }
    return user.hasPhoneNumber
        ? context.translate('profile_ready_checkout')
        : context.translate('profile_add_phone');
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.20),
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 42,
        backgroundColor: AppColors.greyLight,
        backgroundImage: user?.profileImageUrl != null
            ? NetworkImage(user!.profileImageUrl!)
            : const NetworkImage(
                'https://ui-avatars.com/api/?background=2B6EF6&color=fff&size=200&name=Sahla',
              ),
      ),
    );
  }
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _ShortcutGrid extends StatelessWidget {
  const _ShortcutGrid({required this.items});

  final List<_ShortcutItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: constraints.maxWidth >= 720 ? 220 : 190,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: constraints.maxWidth >= 720 ? 170 : 182,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _ShortcutCard(item: item);
          },
        );
      },
    );
  }
}

class _ShortcutCard extends StatefulWidget {
  const _ShortcutCard({required this.item});

  final _ShortcutItem item;

  @override
  State<_ShortcutCard> createState() => _ShortcutCardState();
}

class _ShortcutCardState extends State<_ShortcutCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.item.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _isPressed ? 0.98 : 1,
        child: AppSurfaceCard(
          radius: 24,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: widget.item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        widget.item.icon,
                        color: widget.item.color,
                        size: 22,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      AppIcons.caretRight,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  widget.item.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.item.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionIntro(
          title: context.translate('account_tools_title'),
          subtitle: context.translate('account_tools_subtitle'),
        ),
        const SizedBox(height: 14),
        AppSurfaceCard(
          radius: 28,
          child: Column(
            children: [
              _MenuTile(
                icon: AppIcons.mapPin,
                iconColor: const Color(0xFF14B8A6),
                title: context.translate('shipping_address'),
                subtitle: context.translate(
                  'keep_delivery_locations_organized',
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddressManagementPage(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _MenuTile(
                icon: AppIcons.wallet,
                iconColor: const Color(0xFFF59E0B),
                title: context.translate('payment_methods'),
                subtitle: context.translate('manage_checkout_methods'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PaymentMethodsPage(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _MenuTile(
                icon: AppIcons.settings,
                iconColor: const Color(0xFF8B5CF6),
                title: context.translate('settings'),
                subtitle: context.translate('settings_summary'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SupportSection extends StatelessWidget {
  const _SupportSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionIntro(
          title: context.translate('support_info_title'),
          subtitle: context.translate('support_info_subtitle'),
        ),
        const SizedBox(height: 14),
        AppSurfaceCard(
          radius: 28,
          child: Column(
            children: [
              _MenuTile(
                icon: AppIcons.support,
                iconColor: const Color(0xFF0EA5E9),
                title: context.translate('help_center'),
                subtitle: context.translate('contact_support_resolve'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ContactSupportPage(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _MenuTile(
                icon: AppIcons.info,
                iconColor: const Color(0xFFE35D7B),
                title: context.translate('about_sahla'),
                subtitle: context.translate('read_more_marketplace'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutUsPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogoutCard extends StatelessWidget {
  const _LogoutCard({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      radius: 28,
      borderColor: Colors.redAccent.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                AppIcons.logout,
                color: Colors.redAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.translate('logout'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.translate('logout_device_hint'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onLogout,
              child: Text(
                context.translate('logout'),
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderStats extends StatefulWidget {
  const _OrderStats();

  @override
  State<_OrderStats> createState() => _OrderStatsState();
}

class _OrderStatsState extends State<_OrderStats> {
  bool _startedStreaming = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedStreaming) {
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _startedStreaming = true;
      context.read<OrderBloc>().add(StreamBuyerOrders(authState.user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrderBloc, OrderState>(
      builder: (context, state) {
        final orders = state is OrdersLoaded ? state.orders : const [];
        final processingCount = orders
            .where((order) => order.status.toLowerCase() == 'processing')
            .length;
        final shippedCount = orders
            .where((order) => order.status.toLowerCase() == 'shipped')
            .length;
        final cancelledCount = orders
            .where((order) => order.status.toLowerCase() == 'cancelled')
            .length;
        final reviewCount = orders
            .where(
              (order) =>
                  order.status.toLowerCase() == 'delivered' ||
                  order.status.toLowerCase() == 'received',
            )
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionIntro(
              title: context.translate('order_insights_title'),
              subtitle: context.translate('order_insights_subtitle'),
            ),
            const SizedBox(height: 14),
            AppSurfaceCard(
              radius: 28,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatItem(
                            label: context.translate('processing_filter'),
                            caption: context.translate('awaiting_completion'),
                            statusToken: 'processing',
                            icon: AppIcons.wallet,
                            accent: AppColors.primary,
                            count: processingCount,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatItem(
                            label: context.translate('shipped_filter'),
                            caption: context.translate('packages_in_transit'),
                            statusToken: 'shipped',
                            icon: AppIcons.shipping,
                            accent: const Color(0xFF14B8A6),
                            count: shippedCount,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatItem(
                            label: context.translate('cancelled_filter'),
                            caption: context.translate('orders_stopped'),
                            statusToken: 'cancelled',
                            icon: AppIcons.orders,
                            accent: const Color(0xFFE35D7B),
                            count: cancelledCount,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatItem(
                            label: context.translate('to_review'),
                            caption: context.translate('review_ready_items'),
                            statusToken: 'to_review',
                            icon: AppIcons.review,
                            accent: const Color(0xFFF59E0B),
                            count: reviewCount,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatItem extends StatefulWidget {
  const _StatItem({
    required this.label,
    required this.caption,
    required this.statusToken,
    required this.icon,
    required this.accent,
    required this.count,
  });

  final String label;
  final String caption;
  final String statusToken;
  final IconData icon;
  final Color accent;
  final int count;

  @override
  State<_StatItem> createState() => _StatItemState();
}

class _StatItemState extends State<_StatItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MyOrdersPage(initialStatus: widget.statusToken),
          ),
        );
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _isPressed ? 0.98 : 1,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: widget.accent.withValues(alpha: 0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: widget.accent, size: 20),
              ),
              const SizedBox(height: 18),
              Text(
                '${widget.count}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                widget.caption,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
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
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _isPressed ? 0.94 : 1,
        child: Container(
          margin: const EdgeInsetsDirectional.only(start: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.84),
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: theme.colorScheme.onSurface,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ),
      trailing: Icon(
        AppIcons.caretRight,
        size: 14,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
      ),
      onTap: onTap,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.code,
    required this.onSelected,
  });

  final String label;
  final String code;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      onTap: onSelected,
      trailing: context.read<LanguageBloc>().state.locale.languageCode == code
          ? const Icon(Icons.check, color: AppColors.primary)
          : null,
    );
  }
}

class _ShortcutItem {
  const _ShortcutItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
