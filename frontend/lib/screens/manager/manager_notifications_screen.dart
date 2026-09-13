import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/notification_item.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/glass/glass_card.dart';

class ManagerNotificationsScreen extends StatefulWidget {
  const ManagerNotificationsScreen({super.key});

  @override
  State<ManagerNotificationsScreen> createState() =>
      _ManagerNotificationsScreenState();
}

class _ManagerNotificationsScreenState
    extends State<ManagerNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hr = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hr:$min';
  }

  void _onNotificationTapped(NotificationItem notification) async {
    final provider = context.read<NotificationProvider>();
    if (!notification.isRead) {
      await provider.markAsRead(notification.id);
    }
    if (!mounted) return;

    if (notification.jobId != null && notification.jobId!.isNotEmpty) {
      Navigator.of(context).pushNamed('/manager/jobs/${notification.jobId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null &&
              provider.notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: AppTheme.space8),
                    ElevatedButton(
                      onPressed: () => provider.fetchNotifications(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.notifications.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => provider.fetchNotifications(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80.0),
                    child: Center(child: Text('No notifications available')),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => provider.fetchNotifications(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppTheme.space16),
              itemCount: provider.notifications.length,
              itemBuilder: (context, index) {
                final notification = provider.notifications[index];
                final isUnread = !notification.isRead;

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    onTap: () => _onNotificationTapped(notification),
                    child: GlassCard(
                      padding: const EdgeInsets.all(AppTheme.space16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isUnread
                                  ? AppTheme.primaryBlue
                                  : Colors.transparent,
                            ),
                          ),
                          const SizedBox(width: AppTheme.space12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notification.message,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: isUnread
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: isUnread
                                            ? AppTheme.textPrimary
                                            : AppTheme.textSecondary,
                                      ),
                                ),
                                const SizedBox(height: AppTheme.space8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatTimestamp(notification.createdAt),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppTheme.textMuted,
                                          ),
                                    ),
                                    if (isUnread)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryLight
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'NEW',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.primaryBlue,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
