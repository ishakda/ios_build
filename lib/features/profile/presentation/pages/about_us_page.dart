import 'package:flutter/material.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/features/profile/presentation/widgets/profile_page_shell.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfilePageShell(
      title: context.translate('about_sahla'),
      subtitle: context.translate('about_mission_body'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          AppSurfaceCard(
            radius: 30,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.72),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Icon(
                      AppIcons.basket,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.translate('about_app_name'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.translate('about_app_version'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          AppSurfaceCard(
            radius: 28,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.translate('about_mission_title'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  context.translate('about_mission_body'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.55),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ProfileSectionHeading(
            title: context.translate('about_why_title'),
            subtitle: context.translate('about_core_reasons_subtitle'),
          ),
          const SizedBox(height: 14),
          _FeatureCard(
            icon: AppIcons.check,
            title: context.translate('about_feature_auth_title'),
            desc: context.translate('about_feature_auth_desc'),
          ),
          _FeatureCard(
            icon: AppIcons.shipping,
            title: context.translate('about_feature_delivery_title'),
            desc: context.translate('about_feature_delivery_desc'),
          ),
          _FeatureCard(
            icon: AppIcons.support,
            title: context.translate('about_feature_support_title'),
            desc: context.translate('about_feature_support_desc'),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.desc,
  });

  final IconData icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppSurfaceCard(
        radius: 24,
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
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
}
