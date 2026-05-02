import 'package:flutter/material.dart';

class AppSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? borderColor;
  final double borderWidth;

  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = 24,
    this.borderColor,
    this.borderWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surface.withValues(alpha: isDark ? 0.95 : 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color:
              borderColor ?? theme.colorScheme.outline.withValues(alpha: 0.18),
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
            blurRadius: isDark ? 22 : 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
