import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/job_provider.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/primary_action_button.dart';
import '../../widgets/glass/glass_card.dart';

/// Manager form for creating a new manufacturing job.
class ManagerCreateJobScreen extends StatefulWidget {
  const ManagerCreateJobScreen({super.key});

  @override
  State<ManagerCreateJobScreen> createState() => _ManagerCreateJobScreenState();
}

class _ManagerCreateJobScreenState extends State<ManagerCreateJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jobNumberController = TextEditingController();
  final _companyNameController = TextEditingController();

  @override
  void dispose() {
    _jobNumberController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final provider = context.read<JobProvider>();
    if (provider.isCreatingManagerJob || !_formKey.currentState!.validate()) {
      return;
    }

    final createdJob = await provider.createManagerJob(
      jobNumber: _jobNumberController.text.trim(),
      companyName: _companyNameController.text.trim(),
    );
    if (!mounted || createdJob == null) {
      return;
    }

    _formKey.currentState!.reset();
    _jobNumberController.clear();
    _companyNameController.clear();
    Navigator.of(context).pop(createdJob);
  }

  String? _requiredValue(String? value, String label) {
    if ((value ?? '').trim().isEmpty) {
      return '$label is required.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JobProvider>();
    final isLoading = provider.isCreatingManagerJob;

    return AppScaffold(
      title: 'Create Job',
      showBackButton: true,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.space24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: GlassCard(
              padding: const EdgeInsets.all(AppTheme.space24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'New Manufacturing Job',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      'Enter the job and customer details to begin production.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppTheme.space24),
                    TextFormField(
                      key: const Key('create-job-number-field'),
                      controller: _jobNumberController,
                      enabled: !isLoading,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Job Number',
                        prefixIcon: Icon(Icons.confirmation_number_outlined),
                      ),
                      validator: (value) => _requiredValue(value, 'Job Number'),
                    ),
                    const SizedBox(height: AppTheme.space16),
                    TextFormField(
                      key: const Key('create-company-name-field'),
                      controller: _companyNameController,
                      enabled: !isLoading,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Company Name',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                      validator: (value) =>
                          _requiredValue(value, 'Company Name'),
                    ),
                    if (provider.managerCreateErrorMessage != null) ...[
                      const SizedBox(height: AppTheme.space16),
                      Text(
                        provider.managerCreateErrorMessage!,
                        style: const TextStyle(color: AppTheme.statusCancelled),
                      ),
                    ],
                    const SizedBox(height: AppTheme.space24),
                    PrimaryActionButton(
                      label: 'Create Job',
                      icon: Icons.add_task_outlined,
                      isLoading: isLoading,
                      onPressed: isLoading ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
