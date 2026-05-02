import 'package:flutter/material.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/features/profile/presentation/widgets/profile_page_shell.dart';

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ProfilePageShell(
      title: context.translate('terms_conditions'),
      subtitle: context.translate('terms_intro'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          AppSurfaceCard(
            padding: const EdgeInsets.all(18),
            child: Text(
              '${context.translate('legal_effective_date')}\n\n'
              '${context.translate('terms_intro')}',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          _LegalSection(
            title: context.translate('terms_section_1_title'),
            content: context.translate('terms_section_1_body'),
          ),
          _LegalSection(
            title: context.translate('terms_section_2_title'),
            content: context.translate('terms_section_2_body'),
          ),
          _LegalSection(
            title: context.translate('terms_section_3_title'),
            content: context.translate('terms_section_3_body'),
          ),
          _LegalSection(
            title: context.translate('terms_section_4_title'),
            content: context.translate('terms_section_4_body'),
          ),
          _LegalSection(
            title: context.translate('terms_section_5_title'),
            content: context.translate('terms_section_5_body'),
          ),
          _LegalSection(
            title: context.translate('terms_section_6_title'),
            content: context.translate('terms_section_6_body'),
          ),
          _LegalSection(
            title: context.translate('terms_section_7_title'),
            content: context.translate('terms_section_7_body'),
          ),
          _LegalSection(
            title: context.translate('terms_section_8_title'),
            content: context.translate('terms_section_8_body'),
          ),
        ],
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
