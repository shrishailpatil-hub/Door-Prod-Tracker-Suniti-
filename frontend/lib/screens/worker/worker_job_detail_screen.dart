// lib/screens/worker/worker_job_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/job.dart';
import '../../providers/job_provider.dart';
import '../../widgets/glass/glass_card.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/steps/job_step_card.dart';

class WorkerJobDetailScreen extends StatefulWidget {
  final String jobId;

  const WorkerJobDetailScreen({Key? key, required this.jobId})
    : super(key: key);

  @override
  State<WorkerJobDetailScreen> createState() => _WorkerJobDetailScreenState();
}

class _WorkerJobDetailScreenState extends State<WorkerJobDetailScreen> {
  late final TextEditingController _chalanController;
  String _chalanText = '';

  @override
  void initState() {
    super.initState();
    _chalanController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JobProvider>().fetchJobDetail(widget.jobId);
    });
  }

  @override
  void dispose() {
    // Clear selected job in provider (guarded for mocks)
    try {
      context.read<JobProvider>().clearSelectedJob();
    } catch (_) {
      // ignore if mock does not implement
    }
    _chalanController.dispose();
    super.dispose();
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
          if (jobProvider.isDetailLoading && jobProvider.selectedJob == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (jobProvider.detailErrorMessage != null) {
            final isNotFound = jobProvider.detailErrorMessage!.contains('404');
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isNotFound ? 'Job not found.' : 'Unable to load this job.',
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => jobProvider.fetchJobDetail(widget.jobId),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final Job job = jobProvider.selectedJob!;

          // Show any step action error as a SnackBar
          if (jobProvider.stepActionError != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(jobProvider.stepActionError!)),
              );
              try {
                jobProvider.clearStepActionError();
              } catch (_) {
                // ignore if mock does not implement
              }
            });
          }

          // Show any job‑level action error as a SnackBar
          if (jobProvider.actionError != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(jobProvider.actionError!)));
              try {
                jobProvider.clearActionError();
              } catch (_) {
                // ignore if mock does not implement
              }
            });
          }

          // Populate chalan controller when we have a value
          if (job.chalanNumber != null &&
              _chalanController.text != job.chalanNumber) {
            _chalanController.text = job.chalanNumber!;
            _chalanText = job.chalanNumber!;
          }

          final steps = List<JobStep>.from(job.steps)
            ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
          final firstPendingIndex = steps.indexWhere(
            (s) => s.status == JobStepStatus.pending,
          );

          // Determine the latest completed step for undo action
          final JobStep? latestCompletedStep =
              steps.where((s) => s.status == JobStepStatus.completed).isNotEmpty
              ? steps.where((s) => s.status == JobStepStatus.completed).last
              : null;

          return RefreshIndicator(
            onRefresh: () async => jobProvider.fetchJobDetail(widget.jobId),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              children: [
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'JOB #${job.jobNumber}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          job.companyName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        _buildJobStatusChip(job.status),
                        const SizedBox(height: 8),
                        Text(
                          '${job.completedSteps} / ${job.totalSteps} steps completed',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: job.totalSteps == 0
                              ? 0
                              : job.completedSteps / job.totalSteps,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Step cards
                ...steps.map((step) {
                  final isCurrent =
                      steps.indexOf(step) == firstPendingIndex &&
                      step.status == JobStepStatus.pending;
                  VoidCallback? onComplete;
                  VoidCallback? onUndo;
                  if (isCurrent && job.status == 'IN_PROGRESS') {
                    onComplete = () => jobProvider.completeStep(step.id);
                  }
                  if (latestCompletedStep != null &&
                      latestCompletedStep.id == step.id &&
                      job.status == 'IN_PROGRESS') {
                    onUndo = () => jobProvider.undoStep(step.id);
                  }
                  final isLoading = jobProvider.actionLoadingStepId == step.id;
                  return JobStepCard(
                    step: step,
                    isCurrent: isCurrent,
                    onComplete: onComplete,
                    onUndo: onUndo,
                    isActionLoading: isLoading,
                  );
                }).toList(),
                // Additional UI for WORK_DONE state
                if (job.status == 'WORK_DONE') ...[
                  const SizedBox(height: 24),
                  Text(
                    'Chalan Number',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _chalanController,
                    decoration: InputDecoration(
                      hintText: 'Enter chalan number',
                      suffixIcon: jobProvider.actionLoadingJobId == job.id
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                    enabled:
                        job.chalanNumber == null || job.chalanNumber!.isEmpty,
                    onChanged: (value) {
                      setState(() {
                        _chalanText = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed:
                        (jobProvider.actionLoadingJobId == null &&
                            _chalanText.trim().isNotEmpty &&
                            (job.chalanNumber == null ||
                                job.chalanNumber!.isEmpty))
                        ? () async {
                            await jobProvider.addChalan(
                              job.id,
                              _chalanText.trim(),
                            );
                          }
                        : null,
                    child: const Text('Save Chalan'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed:
                        (jobProvider.actionLoadingJobId == null &&
                            (job.chalanNumber?.trim().isNotEmpty ?? false))
                        ? () async {
                            await jobProvider.completeJob(job.id);
                          }
                        : null,
                    child: const Text('Job Completed'),
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
