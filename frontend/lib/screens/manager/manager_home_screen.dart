// lib/screens/manager/manager_home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/job.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../providers/notification_provider.dart';

class ManagerHomeScreen extends StatelessWidget {
  const ManagerHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    // Use a post‑frame callback to trigger the fetch only once when the screen is first displayed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<JobProvider>(context, listen: false);
      if (!provider.isManagerLoading &&
          provider.managerJobs.isEmpty &&
          provider.managerErrorMessage == null) {
        provider.fetchManagerJobs();
      }
      final notifProvider = Provider.of<NotificationProvider?>(context, listen: false);
      if (notifProvider != null && !notifProvider.isLoading) {
        notifProvider.fetchNotifications();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
        actions: [
          Consumer<NotificationProvider?>(
            builder: (context, notifProvider, _) {
              final unread = notifProvider?.unreadCount ?? 0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.of(context).pushNamed('/manager/notifications');
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_task_outlined),
            tooltip: 'Create Job',
            onPressed: () async {
              final createdJob = await Navigator.of(
                context,
              ).pushNamed('/manager/jobs/create');
              if (context.mounted && createdJob != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Job created successfully.')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'Audit Logs',
            onPressed: () {
              Navigator.of(context).pushNamed('/manager/logs');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await auth.logout();
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => Provider.of<JobProvider>(
          context,
          listen: false,
        ).refreshManagerJobs(),
        child: Consumer<JobProvider>(
          builder: (context, jobProvider, _) {
            if (jobProvider.isManagerLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (jobProvider.managerErrorMessage != null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      jobProvider.managerErrorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => jobProvider.fetchManagerJobs(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            if (jobProvider.managerJobs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [Center(child: Text('No active jobs'))],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              itemCount: jobProvider.managerJobs.length,
              itemBuilder: (context, index) {
                final job = jobProvider.managerJobs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _ManagerJobCard(
                    job: job,
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pushNamed('/manager/jobs/${job.id}');
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ManagerJobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;

  const _ManagerJobCard({required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progressText = "${job.completedSteps} / ${job.totalSteps} steps";
    final nextStepName = job.nextStep?.stepName ?? 'All steps completed';
    
    // Using a subtle Glassmorphism card for Manager Dashboard
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20), // Matches AppTheme.radiusLarge
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0), // AppTheme.space16
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Premium gradient badge for Job number
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1E88E5).withValues(alpha: 0.7), // primaryLight
                        const Color(0xFF1565C0), // primaryBlue
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14), // radiusMedium
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.assignment_turned_in_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              job.jobNumber,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status chip style
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7), // statusPendingBg
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              job.status,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFD97706),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job.companyName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4A5568), // textSecondary
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF718096)),
                          const SizedBox(width: 6),
                          Text(
                            progressText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF718096), // textMuted
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF1565C0)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Next: $nextStepName",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1565C0), // primaryBlue
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}
