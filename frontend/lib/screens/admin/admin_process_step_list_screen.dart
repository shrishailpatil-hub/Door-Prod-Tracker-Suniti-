// Updated admin_process_step_list_screen.dart with callback for edit dialog
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/admin/process_step.dart';
import '../../providers/admin_process_step_provider.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/glass/glass_card.dart';

/// Screen displaying the list of manufacturing process steps for administration.
class AdminProcessStepListScreen extends StatefulWidget {
  const AdminProcessStepListScreen({super.key});

  @override
  State<AdminProcessStepListScreen> createState() => _AdminProcessStepListScreenState();
}

class _AdminProcessStepListScreenState extends State<AdminProcessStepListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AdminProcessStepProvider>();
      if (!provider.isLoading && provider.errorMessage == null) {
        provider.fetchProcessSteps();
      }
    });
  }

  // Helper to show the Create Process Step dialog
  void _showCreateDialog(BuildContext context) {
    final provider = Provider.of<AdminProcessStepProvider>(context, listen: false);
    final _formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final orderController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final maxOrder = provider.activeSteps.length + 1;
        return AlertDialog(
          title: const Text('Create Process Step'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Step Name'),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Name required' : null,
                ),
                TextFormField(
                  controller: orderController,
                  decoration: const InputDecoration(labelText: 'Step Order'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final intVal = int.tryParse(value ?? '');
                    if (intVal == null || intVal < 1 || intVal > maxOrder) {
                      return 'Order must be between 1 and $maxOrder';
                    }
                    return null;
                  },
                ),
                if (provider.createErrorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      provider.createErrorMessage!,
                      style: const TextStyle(color: AppTheme.statusCancelled),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: provider.isCreating
                  ? null
                  : () async {
                      if (_formKey.currentState?.validate() ?? false) {
                        final name = nameController.text.trim();
                        final order = int.parse(orderController.text.trim());
                        final success = await provider.createProcessStep(name: name, stepOrder: order);
                        if (success) {
                          Navigator.of(context).pop();
                        }
                      }
                    },
              child: provider.isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  // Helper to show the Edit Process Step dialog
  void _showEditDialog(BuildContext context, ProcessStep step) {
    final provider = Provider.of<AdminProcessStepProvider>(context, listen: false);
    final _formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: step.name);
    final orderController = TextEditingController(text: step.stepOrder.toString());

    showDialog(
      context: context,
      builder: (context) {
        final maxOrder = provider.activeSteps.length; // edit range
        return AlertDialog(
          title: const Text('Edit Process Step'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Step Name'),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Name required' : null,
                ),
                TextFormField(
                  controller: orderController,
                  decoration: const InputDecoration(labelText: 'Step Order'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final intVal = int.tryParse(value ?? '');
                    if (intVal == null || intVal < 1 || intVal > maxOrder) {
                      return 'Order must be between 1 and $maxOrder';
                    }
                    return null;
                  },
                ),
                if (provider.updateErrorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      provider.updateErrorMessage!,
                      style: const TextStyle(color: AppTheme.statusCancelled),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: provider.isUpdating
                  ? null
                  : () async {
                      if (_formKey.currentState?.validate() ?? false) {
                        final name = nameController.text.trim();
                        final order = int.parse(orderController.text.trim());
                        final success = await provider.updateProcessStep(id: step.id, name: name, stepOrder: order);
                        if (success) {
                          Navigator.of(context).pop();
                        }
                      }
                    },
              child: provider.isUpdating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Helper to show the Deactivate Process Step confirmation dialog
  void _showDeactivateDialog(BuildContext context, ProcessStep step) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        // Capture the outer provider instance
        final outerProv = Provider.of<AdminProcessStepProvider>(context, listen: false);
        return ChangeNotifierProvider<AdminProcessStepProvider>.value(
          value: outerProv,
          child: Consumer<AdminProcessStepProvider>(
            builder: (c, prov, _) => AlertDialog(
              title: const Text('Deactivate Process Step'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'The selected step will become inactive and will no longer be included in newly created Jobs. Remaining active steps will be automatically reordered. Existing Jobs are unaffected because they use workflow snapshots.',
                  ),
                  const SizedBox(height: 12),
                  if (prov.deactivateErrorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        prov.deactivateErrorMessage!,
                        style: const TextStyle(color: AppTheme.statusCancelled),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  key: const Key('deactivateButton'),
                  onPressed: prov.isDeactivating
                      ? null
                      : () async {
                          final success = await prov.deactivateProcessStep(step.id);
                          if (success) {
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Process step deactivated')),
                            );
                          }
                        },
                  child: const Text('Deactivate'),
                ),
                if (prov.isDeactivating) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper to show the Reactivate Process Step confirmation dialog
  void _showReactivateDialog(BuildContext context, ProcessStep step) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final outerProv = Provider.of<AdminProcessStepProvider>(context, listen: false);
        return ChangeNotifierProvider<AdminProcessStepProvider>.value(
          value: outerProv,
          child: Consumer<AdminProcessStepProvider>(
            builder: (c, prov, _) => AlertDialog(
              title: const Text('Reactivate Process Step'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to reactivate "${step.name}"?\n\nIt will be added to the end of the active process steps.',
                  ),
                  if (prov.reactivateErrorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text(
                        prov.reactivateErrorMessage!,
                        style: const TextStyle(color: AppTheme.statusCancelled),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  key: const Key('confirmReactivateButton'),
                  onPressed: prov.isReactivating
                      ? null
                      : () async {
                          final navigator = Navigator.of(dialogContext);
                          final messenger = ScaffoldMessenger.of(context);
                          final success = await prov.reactivateProcessStep(step.id);
                          if (success) {
                            navigator.pop();
                            messenger.showSnackBar(
                              SnackBar(content: Text('Process step "${step.name}" reactivated')),
                            );
                          }
                        },
                  child: const Text('Reactivate'),
                ),
                if (prov.isReactivating) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Process Steps',
      showBackButton: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'Add Process Step',
          onPressed: () => _showCreateDialog(context),
        ),
      ],
      body: Consumer<AdminProcessStepProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.errorMessage!,
                      style: const TextStyle(
                        color: AppTheme.statusCancelled,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.space16),
                    ElevatedButton(
                      onPressed: () => provider.fetchProcessSteps(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final activeSteps = provider.activeSteps;
          final inactiveSteps = provider.inactiveSteps;

          if (activeSteps.isEmpty && inactiveSteps.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => provider.fetchProcessSteps(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(AppTheme.space32),
                    child: Center(
                      child: Text(
                        'No active process steps',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => provider.fetchProcessSteps(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppTheme.space16),
              children: [
                // Active Section
                Row(
                  children: const [
                    Icon(
                      Icons.account_tree_outlined,
                      size: 20,
                      color: AppTheme.primaryBlue,
                    ),
                    SizedBox(width: AppTheme.space8),
                    // Title
                    const Text('ACTIVE PROCESS FLOW', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: AppTheme.space8),
                if (activeSteps.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppTheme.space16),
                    child: Center(
                      child: Text(
                        'No active process steps',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  ...activeSteps.map((step) => Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.space12),
                        child: _ActiveStepCard(
                          step: step,
                          onEdit: _showEditDialog,
                          onDeactivate: _showDeactivateDialog,
                        ),
                      )),
                // Inactive Section
                if (inactiveSteps.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.space16),
                  Row(
                    children: const [
                      Icon(
                        Icons.archive_outlined,
                        size: 20,
                        color: AppTheme.textSecondary,
                      ),
                      SizedBox(width: AppTheme.space8),
                      // Title
                      Text('INACTIVE STEPS', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space8),
                  ...inactiveSteps.map((step) => Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.space12),
                        child: _InactiveStepCard(
                          step: step,
                          onReactivate: _showReactivateDialog,
                        ),
                      )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActiveStepCard extends StatelessWidget {
  final ProcessStep step;
  final void Function(BuildContext, ProcessStep) onEdit;
  final void Function(BuildContext, ProcessStep) onDeactivate;

  const _ActiveStepCard({
    required this.step,
    required this.onEdit,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Order Badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            alignment: Alignment.center,
            child: Text(
              '${step.stepOrder}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryBlue,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          // Step Name, Status, and Actions
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                Wrap(
                  spacing: AppTheme.space8,
                  runSpacing: AppTheme.space4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusChip.completed(label: 'Active'),
                    // Edit action
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
                      icon: const Icon(Icons.edit, size: 20),
                      tooltip: 'Edit step',
                      onPressed: () => onEdit(context, step),
                    ),
                    // Deactivate placeholder action
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: 'Deactivate step',
                      onPressed: () => onDeactivate(context, step),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InactiveStepCard extends StatelessWidget {
  final ProcessStep step;
  final void Function(BuildContext, ProcessStep) onReactivate;

  const _InactiveStepCard({
    required this.step,
    required this.onReactivate,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            alignment: Alignment.center,
            child: Text(
              '${step.stepOrder}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                Wrap(
                  spacing: AppTheme.space8,
                  runSpacing: AppTheme.space4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusChip.completed(label: 'Inactive'),
                    Text(
                      'Previous order: ${step.stepOrder}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    TextButton.icon(
                      key: Key('reactivateButton_${step.id}'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space8, vertical: AppTheme.space4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.restore, size: 18),
                      label: const Text('Reactivate'),
                      onPressed: () => onReactivate(context, step),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
