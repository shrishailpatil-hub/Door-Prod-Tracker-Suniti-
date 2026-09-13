// lib/screens/manager/manager_home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/jobs/job_card.dart';

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
                  child: JobCard(
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
