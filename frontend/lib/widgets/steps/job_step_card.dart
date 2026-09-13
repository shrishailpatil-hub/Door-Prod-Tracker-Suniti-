// lib/widgets/steps/job_step_card.dart

import 'package:flutter/material.dart';
import '../../models/job.dart';

class JobStepCard extends StatelessWidget {
  final JobStep step;
  final bool isCurrent;
  final VoidCallback? onComplete;
  final VoidCallback? onUndo;
  final bool isActionLoading;

  const JobStepCard({
    Key? key,
    required this.step,
    required this.isCurrent,
    this.onComplete,
    this.onUndo,
    this.isActionLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    Color iconColor;
    String statusLabel;

    if (step.status == JobStepStatus.completed) {
      iconData = Icons.check_circle;
      iconColor = Colors.green;
      statusLabel = 'Completed';
    } else if (isCurrent && step.status == JobStepStatus.pending) {
      iconData = Icons.arrow_forward;
      iconColor = Theme.of(context).colorScheme.primary;
      statusLabel = 'Ready';
    } else {
      iconData = Icons.radio_button_unchecked;
      iconColor = Colors.grey;
      statusLabel = 'Waiting';
    }

    // Determine action widget
    Widget? actionWidget;
    if (isActionLoading) {
      actionWidget = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (onComplete != null) {
      actionWidget = ElevatedButton(
        onPressed: onComplete,
        child: const Text('Complete'),
      );
    } else if (onUndo != null) {
      actionWidget = ElevatedButton(
        onPressed: onUndo,
        child: const Text('Undo'),
      );
    }

    return ListTile(
      leading: Icon(iconData, color: iconColor, size: 28),
      title: Text(step.stepName, style: Theme.of(context).textTheme.bodyLarge),
      subtitle:
          step.status == JobStepStatus.completed &&
              (step.completedBy != null || step.completedAt != null)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (step.completedBy != null) Text('By: ${step.completedBy}'),
                if (step.completedAt != null) Text('At: ${step.completedAt}'),
              ],
            )
          : null,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            statusLabel,
            style: TextStyle(color: iconColor, fontWeight: FontWeight.bold),
          ),
          if (actionWidget != null) ...[
            const SizedBox(height: 4),
            actionWidget,
          ],
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      dense: true,
    );
  }
}
