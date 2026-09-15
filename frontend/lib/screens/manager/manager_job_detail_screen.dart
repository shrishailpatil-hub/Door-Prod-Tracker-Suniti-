// lib/screens/manager/manager_job_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/job.dart';
import '../../providers/job_provider.dart';
import '../../widgets/glass/glass_card.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/steps/job_step_card.dart';

class ManagerJobDetailScreen extends StatefulWidget {
  final String jobId;

  const ManagerJobDetailScreen({Key? key, required this.jobId})
    : super(key: key);

  @override
  State<ManagerJobDetailScreen> createState() => _ManagerJobDetailScreenState();
}

class _ManagerJobDetailScreenState extends State<ManagerJobDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JobProvider>().fetchManagerJob(widget.jobId);
    });
  }

  Widget _buildJobStatusChip(String status) {
    switch (status) {
      case 'IN_PROGRESS':
        return StatusChip.inProgress();
      case 'WORK_DONE':
        return StatusChip.completed(label: 'Work Done');
      case 'JOB_COMPLETED':
        return StatusChip.completed(label: 'Completed');
      case 'CANCELLED':
        return StatusChip.cancelled();
      default:
        return StatusChip(
          label: status,
          backgroundColor: Colors.grey,
          textColor: Colors.white,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: Consumer<JobProvider>(
        builder: (context, jobProvider, _) {
          if (jobProvider.isManagerDetailLoading &&
              jobProvider.managerSelectedJob == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (jobProvider.managerDetailErrorMessage != null) {
            final isNotFound = jobProvider.managerDetailErrorMessage!.contains(
              '404',
            );
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isNotFound ? 'Job not found.' : 'Unable to load this job.',
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => jobProvider.fetchManagerJob(widget.jobId),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final Job? job = jobProvider.managerSelectedJob;
          if (job == null) {
            return const Center(child: Text('No job data'));
          }

          final steps = List<JobStep>.from(job.steps)
            ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
          final firstPendingIndex = steps.indexWhere(
            (s) => s.status == JobStepStatus.pending,
          );

          return RefreshIndicator(
            onRefresh: () async => jobProvider.fetchManagerJob(widget.jobId),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              children: [
                GlassCard(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderColor: Colors.white.withValues(alpha: 0.8),
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'JOB #${job.jobNumber}',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    job.companyName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildJobStatusChip(job.status),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '${job.completedSteps} / ${job.totalSteps} steps completed',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: job.totalSteps == 0 ? 0 : job.completedSteps / job.totalSteps,
                            minHeight: 8,
                            backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                          ),
                        ),
                        if (job.chalanNumber != null && job.chalanNumber!.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.receipt_long_rounded, color: AppTheme.textSecondary, size: 20),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Chalan Number',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textMuted,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      job.chalanNumber!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.history_outlined),
                    label: const Text('View Job History'),
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pushNamed('/manager/jobs/${job.id}/logs');
                    },
                  ),
                ),
                // After the GlassCard, add Cancel Job button if applicable
                if (job.status == 'IN_PROGRESS') ...[
                  const SizedBox(height: 16),
                  Center(
                    child:
                        jobProvider.managerCancelLoadingJobId == job.id ||
                            jobProvider.managerReopenLoadingJobId == job.id
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Cancel Job?'),
                                  content: const Text(
                                    'Are you sure you want to cancel this job?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Keep Job'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text('Cancel Job'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await jobProvider.cancelManagerJob(job.id);
                              }
                            },
                            child: const Text('Cancel Job'),
                          ),
                  ),
                ],
                // Show error SnackBar if cancellation failed
                if (jobProvider.managerCancelErrorMessage != null) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              jobProvider.managerCancelErrorMessage!,
                            ),
                          ),
                        );
                      });
                      return const SizedBox.shrink();
                    },
                  ),
                ],
                const SizedBox(height: 16),
                // Steps list continues
                ...steps.map((step) {
                  final isCurrent =
                      steps.indexOf(step) == firstPendingIndex &&
                      step.status == JobStepStatus.pending;
                  // Show Reopen button for completed steps when job is in a reopenable state
                  bool showReopen =
                      job.status == 'WORK_DONE' &&
                      step.status == JobStepStatus.completed;
                  Widget? reopenButton;
                  if (showReopen) {
                    final isLoading =
                        jobProvider.managerReopenLoadingJobId == job.id ||
                        jobProvider.managerCancelLoadingJobId == job.id;
                    reopenButton = isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Reopen from ${step.stepName}?'),
                                  content: const Text(
                                    'This will reopen this step and all later manufacturing steps.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Keep Completed'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text('Reopen'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await jobProvider.reopenManagerJob(
                                  job.id,
                                  step.id,
                                );
                              }
                            },
                            child: const Text('Reopen'),
                          );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      JobStepCard(
                        step: step,
                        isCurrent: isCurrent,
                        onComplete: null,
                        onUndo: null,
                        isActionLoading: false,
                      ),
                      if (reopenButton != null) ...[
                        const SizedBox(height: 4),
                        reopenButton,
                      ],
                    ],
                  );
                }).toList(),
                // Show error SnackBar if reopen failed
                if (jobProvider.managerReopenErrorMessage != null) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              jobProvider.managerReopenErrorMessage!,
                            ),
                          ),
                        );
                      });
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
