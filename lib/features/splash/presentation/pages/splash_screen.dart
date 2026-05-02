import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:untitled1/core/theme/app_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.isLoading = false});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseTextColor = isDark ? Colors.white : const Color(0xFF172033);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.darkBgGradient
              : const LinearGradient(
                  colors: [Color(0xFFF7F8FB), Color(0xFFEEF2F8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
            ).animate().fadeIn(duration: 700.ms).scale(),
            Positioned(
              bottom: -120,
              right: -100,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.08),
                ),
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 700.ms).scale(),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.darkSurface : Colors.white)
                              .withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.18),
                              blurRadius: 32,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/logopng.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 900.ms)
                      .scale(
                        begin: const Offset(0.72, 0.72),
                        curve: Curves.easeOutBack,
                      )
                      .then()
                      .shimmer(duration: 1200.ms),
                  const SizedBox(height: 28),
                  Text(
                    'SAHLA',
                    style: TextStyle(
                      color: baseTextColor,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                    ),
                  ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.25, end: 0),
                  const SizedBox(height: 10),
                  Text(
                    'Everything you need, simply.',
                    style: TextStyle(
                      color: baseTextColor.withValues(alpha: 0.68),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ).animate().fadeIn(delay: 450.ms),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 54,
              child: Column(
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 180,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child:
                          Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              )
                              .animate(
                                onPlay: (controller) => controller.repeat(),
                              )
                              .custom(
                                duration: 1600.ms,
                                builder: (context, value, child) =>
                                      FractionallySizedBox(
                                      alignment: AlignmentDirectional.centerStart,
                                        widthFactor: value,
                                      child: child,
                                    ),
                              ),
                    ),
                ],
              ).animate().fadeIn(delay: 700.ms),
            ),
          ],
        ),
      ),
    );
  }
}
