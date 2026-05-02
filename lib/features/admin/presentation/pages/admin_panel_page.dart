import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_empty_state.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:untitled1/core/widgets/app_page_intro_card.dart';
import 'package:untitled1/core/widgets/app_surface_card.dart';
import 'package:untitled1/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:untitled1/features/admin/presentation/cubit/admin_users_state.dart';
import 'package:untitled1/features/admin/presentation/widgets/admin_panel_sections.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:untitled1/features/auth/presentation/bloc/auth_state.dart';
import 'package:untitled1/injection_container.dart';

class AdminPanelPage extends StatelessWidget {
  const AdminPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUser = authState is Authenticated ? authState.user : null;

    if (currentUser == null || !currentUser.isAdmin) {
      return AppGradientScaffold(
        appBar: AppBar(title: Text(context.translate('admin_panel'))),
        body: AppEmptyState(
          icon: AppIcons.warning,
          title: context.translate('access_denied'),
          subtitle: context.translate('admin_only_page'),
          accentColor: Colors.redAccent,
        ),
      );
    }

    return BlocProvider(
      create: (_) => sl<AdminUsersCubit>()..load(),
      child: _AdminPanelView(currentUser: currentUser),
    );
  }
}

class _AdminPanelView extends StatefulWidget {
  const _AdminPanelView({required this.currentUser});

  final User currentUser;

  @override
  State<_AdminPanelView> createState() => _AdminPanelViewState();
}

class _AdminPanelViewState extends State<_AdminPanelView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String?> _showNoteDialog({
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(context.translate('confirm')),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminUsersCubit, AdminUsersState>(
      listener: (context, state) => handleAdminPanelFeedback(context, state),
      builder: (context, state) {
        return DefaultTabController(
          length: 5,
          child: AppGradientScaffold(
            appBar: AppBar(
              title: Text(context.translate('admin_panel')),
              bottom: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: context.translate('overview')),
                  Tab(text: context.translate('users')),
                  Tab(text: context.translate('tickets')),
                  Tab(text: context.translate('reports')),
                  Tab(text: context.translate('refunds')),
                ],
              ),
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: AppPageIntroCard(
                    title: context.translate('admin_panel'),
                    trailing: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        AppIcons.warning,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: AppSurfaceCard(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: EdgeInsets.zero,
                    child: RefreshIndicator(
                      onRefresh: () => context.read<AdminUsersCubit>().load(),
                      child: TabBarView(
                        children: [
                          AdminOverviewSection(state: state),
                          AdminUsersSection(
                            state: state,
                            currentUser: widget.currentUser,
                            searchController: _searchController,
                            requestNote: _showNoteDialog,
                          ),
                          AdminTicketsSection(
                            state: state,
                            requestNote: _showNoteDialog,
                          ),
                          AdminReportsSection(
                            state: state,
                            requestNote: _showNoteDialog,
                          ),
                          AdminRefundsSection(
                            state: state,
                            requestNote: _showNoteDialog,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
