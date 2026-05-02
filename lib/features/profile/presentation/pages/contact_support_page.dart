import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:untitled1/core/constants/supabase_constants.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/features/profile/presentation/widgets/profile_page_shell.dart';

class ContactSupportPage extends StatefulWidget {
  const ContactSupportPage({super.key});

  @override
  State<ContactSupportPage> createState() => _ContactSupportPageState();
}

class _ContactSupportPageState extends State<ContactSupportPage> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('sign_in_required'))),
      );
      return;
    }

    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    if (subject.length < 3 || message.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('support_validation_error'))),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await SupabaseService.client.from(SupabaseTables.supportTickets).insert({
        'userId': uid,
        'subject': subject,
        'message': message,
        'contactMethod': 'in_app',
      });
      if (!mounted) return;
      _subjectController.clear();
      _messageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('support_ticket_submitted'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('support_ticket_failed'))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _copyContactValue(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.translate('copied_to_clipboard'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProfilePageShell(
      title: context.translate('help_center'),
      subtitle: context.translate('support_response_time'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          ProfileSectionHeading(
            title: context.translate('support_help_title'),
            subtitle: context.translate('support_shell_subtitle'),
          ),
          const SizedBox(height: 14),
          _buildContactCard(
            icon: AppIcons.email,
            title: context.translate('email_us'),
            value: 'support@sahla.app',
            onTap: () => _copyContactValue('support@sahla.app'),
          ),
          _buildContactCard(
            icon: AppIcons.phone,
            title: context.translate('call_us'),
            value: '+213 542 60 42 15',
            onTap: () => _copyContactValue('+213542604215'),
          ),
          _buildContactCard(
            icon: AppIcons.messages,
            title: context.translate('live_chat'),
            value: context.translate('support_live_chat_hours'),
            onTap: () =>
                _copyContactValue(context.translate('support_live_chat_hours')),
          ),
          const SizedBox(height: 20),
          AppSurfaceCard(
            radius: 28,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.translate('send_message'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _subjectController,
                  decoration: InputDecoration(
                    labelText: context.translate('subject'),
                    prefixIcon: const Icon(AppIcons.note),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: context.translate('message'),
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitTicket,
                    child: Text(
                      _isSubmitting
                          ? context.translate('submitting')
                          : context.translate('send_message'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppSurfaceCard(
        radius: 24,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(height: 1.35),
          ),
          trailing: const Icon(AppIcons.caretRight),
          onTap: onTap,
        ),
      ),
    );
  }
}
