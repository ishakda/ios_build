import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:untitled1/features/auth/presentation/pages/login_page.dart';

class OnboardingPage extends StatefulWidget {
  final Future<void> Function()? onFinished;

  const OnboardingPage({super.key, this.onFinished});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingContent> _contents = [
    OnboardingContent(
      title: 'Premium Selection',
      description:
          'Discover the world\'s finest products from verified vendors at Sahla.',
      icon: AppIcons.sparkles,
    ),
    OnboardingContent(
      title: 'Secure Checkout',
      description:
          'Shop with confidence using our encrypted and fast payment gateways.',
      icon: AppIcons.check,
    ),
    OnboardingContent(
      title: 'Swift Delivery',
      description:
          'Your package is handled with care and delivered right to your door.',
      icon: AppIcons.shipping,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppGradientScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => _finishOnboarding(),
                child: const Text(
                  'Skip',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _contents.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated Brand Icon instead of inconsistent images
                        Container(
                              height: 200,
                              width: 200,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.05,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _contents[index].icon,
                                size: 100,
                                color: AppColors.primary,
                              ),
                            )
                            .animate(key: ValueKey(index))
                            .scale(duration: 600.ms, curve: Curves.easeOutBack)
                            .shimmer(delay: 800.ms, duration: 1500.ms),

                        const SizedBox(height: 60),

                        Text(
                              _contents[index].title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            )
                            .animate(key: ValueKey('t_$index'))
                            .fadeIn(delay: 200.ms)
                            .slideY(begin: 0.2, end: 0),

                        const SizedBox(height: 20),

                        Text(
                              _contents[index].description,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                            .animate(key: ValueKey('d_$index'))
                            .fadeIn(delay: 400.ms),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 40,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Indicator
                  Row(
                    children: List.generate(
                      _contents.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 8,
                        width: _currentPage == index ? 30 : 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  // Action Button
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage == _contents.length - 1) {
                        _finishOnboarding();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOutQuart,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(140, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 8,
                      shadowColor: AppColors.primary.withValues(alpha: 0.4),
                    ),
                    child: Text(
                      _currentPage == _contents.length - 1
                          ? 'Get Started'
                          : 'Next',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ).animate().scale(delay: 200.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finishOnboarding() async {
    if (widget.onFinished != null) {
      await widget.onFinished!();
      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }
}

class OnboardingContent {
  final String title;
  final String description;
  final IconData icon;

  OnboardingContent({
    required this.title,
    required this.description,
    required this.icon,
  });
}
