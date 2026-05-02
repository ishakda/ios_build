import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/features/home/presentation/pages/home_page.dart';
import 'package:untitled1/features/navigation/presentation/cubit/main_navigation_cubit.dart';
import 'package:untitled1/features/cart/presentation/pages/cart_page.dart';
import 'package:untitled1/features/profile/presentation/pages/profile_page.dart';
import 'package:untitled1/features/vendor/presentation/pages/vendor_store_page.dart';
import 'package:untitled1/features/chat/presentation/pages/chat_list_page.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_state.dart';

class MainNavigationContainer extends StatefulWidget {
  const MainNavigationContainer({super.key});

  @override
  State<MainNavigationContainer> createState() =>
      _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer> {
  final MainNavigationCubit _navigationCubit = MainNavigationCubit();

  @override
  void dispose() {
    _navigationCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final theme = Theme.of(context);
        final List<Widget> pages = [
          const HomePage(),
          const ChatListPage(),
          const CartPage(),
          const ProfilePage(),
        ];

        final List<BottomNavigationBarItem> navItems = [
          BottomNavigationBarItem(
            icon: Icon(AppIcons.home),
            activeIcon: Icon(AppIcons.homeActive),
            label: context.translate('home'),
          ),
          BottomNavigationBarItem(
            icon: Icon(AppIcons.messages),
            activeIcon: Icon(AppIcons.messagesActive),
            label: context.translate('messages'),
          ),
          BottomNavigationBarItem(
            icon: Icon(AppIcons.cart),
            activeIcon: Icon(AppIcons.cartActive),
            label: context.translate('cart'),
          ),
          BottomNavigationBarItem(
            icon: Icon(AppIcons.profile),
            activeIcon: Icon(AppIcons.profileActive),
            label: context.translate('profile'),
          ),
        ];

        // If the user is a seller, add the "My Store" tab
        if (state is Authenticated && state.user.role == 'seller') {
          pages.insert(
            1,
            VendorStorePage(
              vendorName: state.user.storeName ?? state.user.name,
            ),
          );
          navItems.insert(
            1,
            BottomNavigationBarItem(
              icon: Icon(AppIcons.store),
              activeIcon: Icon(AppIcons.storeActive),
              label: context.translate('my_store'),
            ),
          );
        }

        return BlocProvider.value(
          value: _navigationCubit,
          child: BlocBuilder<MainNavigationCubit, MainNavigationState>(
            builder: (context, navigationState) {
              final safeIndex = navigationState.selectedIndex >= pages.length
                  ? pages.length - 1
                  : navigationState.selectedIndex;

              if (safeIndex != navigationState.selectedIndex) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _navigationCubit.clampToTabCount(pages.length);
                  }
                });
              }

              return Scaffold(
                extendBody: true,
                backgroundColor: Colors.transparent,
                body: IndexedStack(index: safeIndex, children: pages),
                bottomNavigationBar: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.surface.withValues(alpha: 0.95),
                        theme.colorScheme.surface.withValues(alpha: 0.88),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: NavigationBar(
                      selectedIndex: safeIndex,
                      onDestinationSelected: _navigationCubit.selectTab,
                      destinations: navItems
                          .map(
                            (item) => NavigationDestination(
                              icon: item.icon,
                              selectedIcon: item.activeIcon,
                              label: item.label ?? '',
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
