// lib/widgets/jobs/job_card.dart

import 'package:flutter/material.dart';
import '../../models/job.dart';

import '../../widgets/glass/glass_card.dart'; // GlassCard widget

class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;

  const JobCard({Key? key, required this.job, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progressText = "${job.completedSteps} / ${job.totalSteps} steps";
    final nextStepName = job.nextStep?.stepName ?? 'All steps completed';

    return InkWell(
      onTap: onTap,
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    job.jobNumber,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    job.status,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[800]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                job.companyName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(progressText, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                "Next: $nextStepName",
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
