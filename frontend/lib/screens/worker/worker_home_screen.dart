// lib/screens/worker/worker_home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../widgets/jobs/job_card.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({Key? key}) : super(key: key);

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<JobProvider>(context, listen: false);
      if (!provider.isLoading && provider.errorMessage == null) {
        provider.fetchActiveJobs();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Jobs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await auth.logout();
              if (!mounted) return;
              // After logout, navigate to login screen
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            Provider.of<JobProvider>(context, listen: false).refreshJobs(),
        child: Consumer<JobProvider>(
          builder: (context, jobProvider, _) {
            if (jobProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (jobProvider.errorMessage != null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      jobProvider.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => jobProvider.fetchActiveJobs(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            if (jobProvider.jobs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [Center(child: Text('No active jobs'))],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              itemCount: jobProvider.jobs.length,
              itemBuilder: (context, index) {
                final job = jobProvider.jobs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: JobCard(
                    job: job,
                    onTap: () {
                      Navigator.of(context).pushNamed('/worker/jobs/${job.id}');
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
