// lib/screens/manager/manager_job_detail_placeholder.dart

import 'package:flutter/material.dart';

class ManagerJobDetailPlaceholder extends StatelessWidget {
  final String jobId;
  const ManagerJobDetailPlaceholder({Key? key, required this.jobId})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manager Job Details')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Manager Job Details',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Job ID: $jobId'),
          ],
        ),
      ),
    );
  }
}
