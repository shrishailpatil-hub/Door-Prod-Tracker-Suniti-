// lib/screens/admin/admin_job_logs_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/job_step_history.dart';
import '../../providers/job_provider.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/glass/glass_card.dart';

class AdminJobLogsScreen extends StatefulWidget {
  final String jobId;

  const AdminJobLogsScreen({super.key, required this.jobId});

  @override
  State<AdminJobLogsScreen> createState() => _AdminJobLogsScreenState();
}

class _AdminJobLogsScreenState extends State<AdminJobLogsScreen> {
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
          if (provider.isManagerJobLogsLoading && provider.managerJobLogs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.managerJobLogsErrorMessage != null && provider.managerJobLogs.isEmpty) {
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
                      onPressed: () => provider.fetchManagerJobLogs(widget.jobId),
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
                    color: Colors.white.withValues(alpha: 0.7),
                    borderColor: Colors.white.withValues(alpha: 0.8),
                    padding: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.space16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryBlue.withValues(alpha: 0.15),
                                  AppTheme.primaryBlue.withValues(alpha: 0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.1)),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            ),
                            child: const Icon(Icons.history_outlined, color: AppTheme.primaryBlue),
                          ),
                          const SizedBox(width: AppTheme.space12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: _buildActionBadge(log.action),
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.space8),
                                    Text(
                                      _formatTimestamp(log.createdAt),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.space8),
                                if (log.stepName != null && log.stepName!.isNotEmpty) ...[
                                  Text(
                                    'Step: ${log.stepName}',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                Text(
                                  'By: ${log.performedBy}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
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
