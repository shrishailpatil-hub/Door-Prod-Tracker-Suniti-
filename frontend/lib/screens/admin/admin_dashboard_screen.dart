import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/glass/glass_card.dart';

/// Entry point for administrator-only application modules.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthProvider>().session;

    return AppScaffold(
      title: 'Admin Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_outlined),
          tooltip: 'Logout',
          onPressed: () async {
            await context.read<AuthProvider>().logout();
            if (!context.mounted) return;
            Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
          },
        ),
      ],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 600;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryBlue,
                              AppTheme.primaryDark,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: AppTheme.space16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session?.name ?? 'Administrator',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppTheme.space4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: const Text(
                                'ADMIN',
                                style: TextStyle(
                                  color: AppTheme.primaryBlue,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space24),
                Text('Administration', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: AppTheme.space8),
                const Text('Choose an area to manage the workflow system.', style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: AppTheme.space16),
                GridView.count(
                  crossAxisCount: isTablet ? 2 : 1,
                  crossAxisSpacing: AppTheme.space16,
                  mainAxisSpacing: AppTheme.space16,
                  childAspectRatio: isTablet ? 1.6 : 1.5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: const [
                    _AdminNavigationCard(
                      title: 'User Management',
                      description: 'Manage system users and their access.',
                      icon: Icons.people_outline,
                      routeName: AppRouter.adminUsers,
                    ),
                    _AdminNavigationCard(
                      title: 'Process Steps',
                      description: 'Manage manufacturing process steps.',
                      icon: Icons.account_tree_outlined,
                      routeName: AppRouter.adminProcessSteps,
                    ),
                    _AdminNavigationCard(
                      title: 'Logs / Export',
                      description: 'Access audit logs and export records.',
                      icon: Icons.history_outlined,
                      routeName: AppRouter.adminLogs,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminNavigationCard extends StatelessWidget {
  const _AdminNavigationCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.routeName,
  });

  final String title;
  final String description;
  final IconData icon;
  final String routeName;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => Navigator.of(context).pushNamed(routeName),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryBlue.withValues(alpha: 0.14),
                  AppTheme.primaryLight.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: AppTheme.primaryBlue.withValues(alpha: 0.18),
                width: 1.2,
              ),
            ),
            child: Icon(icon, size: 26, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: AppTheme.space16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.03),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
          ),
        ],
      ),
    );
  }
}
