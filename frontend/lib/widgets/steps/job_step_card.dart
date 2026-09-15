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

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(iconData, color: iconColor, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.stepName,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (step.status == JobStepStatus.completed &&
                (step.completedBy != null || step.completedAt != null))
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 36.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (step.completedBy != null) Text('By: ${step.completedBy}'),
                    if (step.completedAt != null) Text('At: ${step.completedAt}'),
                  ],
                ),
              ),
            if (actionWidget != null) ...[
              const SizedBox(height: 8),
              Center(child: actionWidget),
            ],
          ],
        ),
      ),
    );
  }
}
