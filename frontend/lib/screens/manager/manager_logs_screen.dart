// lib/screens/manager/manager_logs_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/file_export_helper.dart';
import '../../models/job_step_history.dart';
import '../../providers/job_provider.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/glass/glass_card.dart';

class ManagerLogsScreen extends StatefulWidget {
  const ManagerLogsScreen({
    super.key,
    this.fileExportHelper = const FileExportHelper(),
  });

  final FileExportHelper fileExportHelper;

  @override
  State<ManagerLogsScreen> createState() => _ManagerLogsScreenState();
}

class _ManagerLogsScreenState extends State<ManagerLogsScreen> {
  bool _isSaving = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<JobProvider>();
      provider.fetchManagerLogs();
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

  Future<void> _handleExport() async {
    final provider = context.read<JobProvider>();
    if (provider.isExportingExcel || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final bytes = await provider.exportManagerLogsExcel();
      if (!mounted) return;

      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.exportErrorMessage ?? 'Failed to export Excel file',
            ),
          ),
        );
        return;
      }

      final savedFile = await widget.fileExportHelper.saveExcelFile(
        bytes: bytes,
      );
      if (!mounted) return;

      if (savedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export Excel file')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel file exported successfully')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export Excel file')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        actions: [
          Consumer<JobProvider>(
            builder: (context, provider, _) {
              if (provider.isExportingExcel || _isSaving) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.file_download_outlined),
                tooltip: 'Export Excel',
                onPressed: _handleExport,
              );
            },
          ),
        ],
      ),
      body: Consumer<JobProvider>(
        builder: (context, provider, _) {
          if (provider.isManagerLogsLoading &&
              provider.managerAllLogs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.managerLogsErrorMessage != null &&
              provider.managerAllLogs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.managerLogsErrorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: AppTheme.space8),
                    ElevatedButton(
                      onPressed: () => provider.fetchManagerLogs(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.managerAllLogs.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => provider.fetchManagerLogs(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80.0),
                    child: Center(child: Text('No audit logs available')),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => provider.fetchManagerLogs(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppTheme.space16),
              itemCount: provider.managerAllLogs.length,
              itemBuilder: (context, index) {
                final log = provider.managerAllLogs[index];
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
                          'Job ID: ${log.jobId}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: AppTheme.space4),
                        Text(
                          'By: ${log.performedBy}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textMuted),
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
