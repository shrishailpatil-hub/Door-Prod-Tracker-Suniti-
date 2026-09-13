import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/auth/app_user.dart';
import '../../models/auth/user_role.dart';
import '../../providers/admin_user_provider.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/glass/glass_card.dart';

class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({super.key});

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AdminUserProvider>();
      if (!provider.isLoading && provider.errorMessage == null) {
        provider.fetchUsers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Users',
      showBackButton: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.person_add_outlined),
          tooltip: 'Add User',
          onPressed: () {
            Navigator.of(context).pushNamed(AppRouter.adminCreateUser);
          },
        ),
      ],
      padding: EdgeInsets.zero,
      body: Consumer<AdminUserProvider>(
        builder: (context, userProvider, _) {
          if (userProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (userProvider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      userProvider.errorMessage!,
                      style: const TextStyle(
                        color: AppTheme.statusCancelled,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.space16),
                    ElevatedButton(
                      onPressed: () => userProvider.fetchUsers(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Show update error (e.g., activate/deactivate failure)
          if (userProvider.updateErrorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space24),
                child: Text(
                  userProvider.updateErrorMessage!,
                  style: const TextStyle(
                    color: AppTheme.statusCancelled,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (userProvider.users.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => userProvider.refreshUsers(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(AppTheme.space32),
                    child: Center(
                      child: Text(
                        'No users found',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => userProvider.refreshUsers(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppTheme.space16),
              itemCount: userProvider.users.length,
              itemBuilder: (context, index) {
                final user = userProvider.users[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space12),
                  child: _UserCard(user: user),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUser user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _roleColor(user.role).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Icon(
                  _roleIcon(user.role),
                  color: _roleColor(user.role),
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      user.email,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        user.isActive
                            ? StatusChip.completed(label: 'Active')
                            : StatusChip.cancelled(label: 'Inactive'),
                        const SizedBox(height: AppTheme.space4),
                        // Action buttons wrap
                        Wrap(
                          spacing: AppTheme.space8,
                          children: [
                            // Activate / Deactivate button
                            // Activate / Deactivate button
                            Consumer<AdminUserProvider>(
                              builder: (context, provider, _) {
                                return IconButton(
                                  constraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    user.isActive ? Icons.toggle_off : Icons.toggle_on,
                                    size: 20,
                                  ),
                                  onPressed: provider.isUpdating ? null : () {
                                      provider.updateUserStatus(
                                        id: user.id,
                                        isActive: !user.isActive,
                                      );
                                    },
                                );
                              },
                            ),
                            // Edit button
                            IconButton(
                              constraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.edit, size: 20),
                              tooltip: 'Edit user',
                              onPressed: () {
                                Navigator.of(context).pushNamed(
                                  AppRouter.adminEditUser,
                                  arguments: user.id,
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          const Divider(height: 1, color: Color(0x1F000000)),
          const SizedBox(height: AppTheme.space8),
          Row(
            children: [
              const Text(
                'ROLE: ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: _roleColor(user.role).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Text(
                  user.role.toBackendString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _roleColor(user.role),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.space8),
              Text(
                '(${user.role.displayName})',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return AppTheme.primaryBlue;
      case UserRole.manager:
        return AppTheme.statusPending;
      case UserRole.worker:
        return AppTheme.statusCompleted;
    }
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings_outlined;
      case UserRole.manager:
        return Icons.manage_accounts_outlined;
      case UserRole.worker:
        return Icons.engineering_outlined;
    }
  }
}
