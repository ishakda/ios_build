import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/localization/language_bloc.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/theme/theme_bloc.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/features/ai/presentation/pages/ai_assistant_page.dart';
import 'package:untitled1/features/profile/presentation/pages/about_us_page.dart';
import 'package:untitled1/features/profile/presentation/pages/contact_support_page.dart';
import 'package:untitled1/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:untitled1/features/profile/presentation/pages/privacy_policy_page.dart';
import 'package:untitled1/features/profile/presentation/pages/terms_conditions_page.dart';
import 'package:untitled1/features/profile/presentation/widgets/profile_page_shell.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Box _settingsBox;
  bool _pushNotifications = true;
  bool _aiSmartMode = true;
  String _country = 'Algeria';
  double _cacheKb = 0;

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settings');
    _pushNotifications = _settingsBox.get(
      'pushNotifications',
      defaultValue: true,
    );
    _aiSmartMode = _settingsBox.get('aiSmartMode', defaultValue: true);
    _country = _settingsBox.get('country', defaultValue: 'Algeria');
    _cacheKb = PaintingBinding.instance.imageCache.currentSizeBytes / 1024;
  }

  void _setPushNotifications(bool value) {
    setState(() => _pushNotifications = value);
    _settingsBox.put('pushNotifications', value);
  }

  void _setAiSmartMode(bool value) {
    setState(() => _aiSmartMode = value);
    _settingsBox.put('aiSmartMode', value);
  }

  void _setCountry(String value) {
    setState(() => _country = value);
    _settingsBox.put('country', value);
  }

  void _clearCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    setState(() {
      _cacheKb = PaintingBinding.instance.imageCache.currentSizeBytes / 1024;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.translate('cache_cleared_success'))),
    );
  }

  void _showCountryPicker() {
    final countries = [
      'Algeria',
      'Egypt',
      'Morocco',
      'Tunisia',
      'Saudi Arabia',
    ];
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: countries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final country = countries[index];
              return ListTile(
                title: Text(country),
                trailing: _country == country
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  _setCountry(country);
                  Navigator.pop(context);
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showLanguageDialog() {
    showDialog<void>(
      context: context,
      builder: (diagContext) => AlertDialog(
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

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeBloc>().state.themeMode == AppTheme.dark;
    final languageCode = context
        .watch<LanguageBloc>()
        .state
        .locale
        .languageCode;
    final languageLabel = switch (languageCode) {
      'ar' => 'Arabic',
      'fr' => 'French',
      _ => 'English',
    };

    return ProfilePageShell(
      title: context.translate('settings'),
      subtitle: context.translate('settings_shell_subtitle'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  AppIcons.search,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  context.translate('search_settings'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SettingsSection(
            title: context.translate('profile'),
            children: [
              _SettingsTile(
                title: context.translate('edit_profile'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfilePage()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsSection(
            title: context.translate('about_sahla'),
            children: [
              _SettingsTile(
                title: context.translate('help_center'),
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
              _SettingsTile(
                title: context.translate('terms_conditions'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TermsConditionsPage(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _SettingsTile(
                title: context.translate('privacy_policy'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsSection(
            title: context.translate('settings'),
            children: [
              _SwitchTile(
                title: context.translate('push_notifications'),
                value: _pushNotifications,
                onChanged: _setPushNotifications,
              ),
              const Divider(height: 1),
              _SettingsTile(
                title: context.translate('country'),
                trailingText: _country.toUpperCase(),
                onTap: _showCountryPicker,
              ),
              const Divider(height: 1),
              _SettingsTile(
                title: context.translate('language'),
                trailingText: languageLabel.toUpperCase(),
                onTap: _showLanguageDialog,
              ),
              const Divider(height: 1),
              _SwitchTile(
                title: context.translate('dark_mode'),
                value: isDark,
                onChanged: (_) => context.read<ThemeBloc>().add(ToggleTheme()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsSection(
            title: 'AI',
            children: [
              _SettingsTile(
                title: context.translate('ai_shopping_assistant'),
                trailingText: context.translate('open').toUpperCase(),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AiAssistantPage()),
                  );
                },
              ),
              const Divider(height: 1),
              _SwitchTile(
                title: context.translate('ai_smart_mode'),
                subtitle: context.translate('ai_smart_mode_subtitle'),
                value: _aiSmartMode,
                onChanged: _setAiSmartMode,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsSection(
            title: context.translate('app_info'),
            children: [
              _SettingsTile(
                title: context.translate('app_version'),
                trailingText: '1.0.0+1',
              ),
              const Divider(height: 1),
              _SettingsTile(
                title: context.translate('cache_used'),
                trailingText: '${_cacheKb.toStringAsFixed(1)} kB',
                trailingActionText: context.translate('clear').toUpperCase(),
                onTrailingActionTap: _clearCache,
              ),
              const Divider(height: 1),
              _SettingsTile(
                title: context.translate('about_app'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutUsPage()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          AppSurfaceCard(
            radius: 20,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  AppIcons.sparkles,
                  color: AppColors.primary.withValues(alpha: 0.9),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.translate('ai_tip'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        AppSurfaceCard(
          radius: 14,
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    this.trailingText,
    this.onTap,
    this.trailingActionText,
    this.onTrailingActionTap,
  });

  final String title;
  final String? trailingText;
  final VoidCallback? onTap;
  final String? trailingActionText;
  final VoidCallback? onTrailingActionTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          if (trailingActionText != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onTrailingActionTap,
              child: Text(
                trailingActionText!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(AppIcons.caretRight, size: 14),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis),
      value: value,
      activeThumbColor: AppColors.primary,
      onChanged: onChanged,
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
