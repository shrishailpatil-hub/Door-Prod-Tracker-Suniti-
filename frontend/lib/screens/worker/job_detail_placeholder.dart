// lib/screens/worker/job_detail_placeholder.dart

import 'package:flutter/material.dart';

class JobDetailPlaceholder extends StatelessWidget {
  final String jobId;

  const JobDetailPlaceholder({Key? key, required this.jobId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Job Details')),
      body: Center(
        child: Text(
          'Details for Job $jobId (placeholder)',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
