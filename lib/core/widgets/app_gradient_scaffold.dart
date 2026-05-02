import 'package:flutter/material.dart';
import 'package:untitled1/core/theme/app_colors.dart';

class AppGradientScaffold extends StatelessWidget {
  const AppGradientScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.drawer,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Widget? drawer;

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
      child: Stack(
        children: [
          _ScaffoldBackdrop(isDark: isDark),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: appBar,
            drawer: drawer,
            body: body,
            floatingActionButton: floatingActionButton,
            bottomNavigationBar: bottomNavigationBar,
            bottomSheet: bottomSheet,
          ),
        ],
      ),
    );
  }
}

class _ScaffoldBackdrop extends StatelessWidget {
  const _ScaffoldBackdrop({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
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
