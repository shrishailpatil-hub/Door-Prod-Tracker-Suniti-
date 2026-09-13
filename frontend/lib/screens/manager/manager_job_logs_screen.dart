// lib/screens/manager/manager_job_logs_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/job_step_history.dart';
import '../../providers/job_provider.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/glass/glass_card.dart';

class ManagerJobLogsScreen extends StatefulWidget {
  final String jobId;

  const ManagerJobLogsScreen({super.key, required this.jobId});

  @override
  State<ManagerJobLogsScreen> createState() => _ManagerJobLogsScreenState();
}

class _ManagerJobLogsScreenState extends State<ManagerJobLogsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<JobProvider>();
      provider.fetchManagerJobLogs(widget.jobId);
    });
  }

  Widget _buildActionBadge(JobStepAction action) {
    switch (action) {
      case JobStepAction.completed:
        return StatusChip.completed(label: 'Step Completed');
      case JobStepAction.undone:
        return const StatusChip(
          label: 'Step Undone',
          backgroundColor: Color(0xFFFEF3C7),
          textColor: Color(0xFFD97706),
          icon: Icons.undo_rounded,
        );
      case JobStepAction.reopened:
        return const StatusChip(
          label: 'Step Reopened',
          backgroundColor: Color(0xFFE0E7FF),
          textColor: Color(0xFF4F46E5),
          icon: Icons.refresh_rounded,
        );
      case JobStepAction.chalanAdded:
        return const StatusChip(
          label: 'Chalan Added',
          backgroundColor: Color(0xFFF3E8FF),
          textColor: Color(0xFF7E22CE),
          icon: Icons.receipt_long_rounded,
        );
      case JobStepAction.jobCompleted:
        return StatusChip.completed(
          label: 'Job Completed',
          icon: Icons.verified_rounded,
        );
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job History')),
      body: Consumer<JobProvider>(
        builder: (context, provider, _) {
          if (provider.isManagerJobLogsLoading &&
              provider.managerJobLogs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.managerJobLogsErrorMessage != null &&
              provider.managerJobLogs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.managerJobLogsErrorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: AppTheme.space8),
                    ElevatedButton(
                      onPressed: () =>
                          provider.fetchManagerJobLogs(widget.jobId),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.managerJobLogs.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => provider.fetchManagerJobLogs(widget.jobId),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80.0),
                    child: Center(child: Text('No history for this job')),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => provider.fetchManagerJobLogs(widget.jobId),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppTheme.space16),
              itemCount: provider.managerJobLogs.length,
              itemBuilder: (context, index) {
                final log = provider.managerJobLogs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space12),
                  child: GlassCard(
                    padding: const EdgeInsets.all(AppTheme.space16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildActionBadge(log.action),
                            Text(
                              _formatTimestamp(log.createdAt),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.space8),
                        if (log.stepName != null &&
                            log.stepName!.isNotEmpty) ...[
                          Text(
                            'Step: ${log.stepName}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppTheme.space4),
                        ],
                        Text(
                          'By: ${log.performedBy}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
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
