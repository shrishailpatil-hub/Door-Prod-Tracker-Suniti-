import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/file_export_helper.dart';
import '../../models/job.dart';
import '../../providers/admin_log_provider.dart';
import '../../providers/job_provider.dart';
import '../../widgets/glass/glass_card.dart';
import 'admin_job_logs_screen.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({
    super.key,
    this.fileExportHelper = const FileExportHelper(),
  });

  final FileExportHelper fileExportHelper;

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<JobProvider>().fetchManagerJobs();
    });
  }

  bool _isActive(Job job) => job.status.toUpperCase() != 'COMPLETED';

  Future<void> _handleExport() async {
    final provider = context.read<AdminLogProvider>();
    if (provider.isExporting || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final bytes = await provider.exportLogsExcel();
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export Excel file')),
      );
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
          Consumer<AdminLogProvider>(
            builder: (context, provider, _) {
              if (provider.isExporting || _isSaving) {
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
          if (provider.isManagerLoading && provider.managerJobs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.managerErrorMessage != null && provider.managerJobs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.managerErrorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: AppTheme.space8),
                    ElevatedButton(
                      onPressed: () => provider.fetchManagerJobs(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final activeJobs = provider.managerJobs.where(_isActive).toList();
          if (activeJobs.isEmpty) {
            return const Center(child: Text('No active jobs available'));
          }

          return RefreshIndicator(
            onRefresh: () async => provider.fetchManagerJobs(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppTheme.space16),
              itemCount: activeJobs.length,
              itemBuilder: (context, index) {
                final job = activeJobs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space12),
                  child: GlassCard(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderColor: Colors.white.withValues(alpha: 0.8),
                    padding: EdgeInsets.zero,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AdminJobLogsScreen(jobId: job.id),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.space16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryBlue.withValues(alpha: 0.7),
                                    AppTheme.primaryBlue,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.assignment_outlined, color: Colors.white),
                            ),
                            const SizedBox(width: AppTheme.space16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Job ${job.jobNumber}', 
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Company: ${job.companyName}', 
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.space8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.statusPendingBg,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppTheme.statusPending.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      'Status: ${job.status}', 
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.statusPending,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                          ],
                        ),
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
