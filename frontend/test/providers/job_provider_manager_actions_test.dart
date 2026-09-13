import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/job.dart';
import 'package:frontend/providers/job_provider.dart';
import 'package:frontend/services/job_service.dart';
import 'package:mocktail/mocktail.dart';

class MockJobService extends Mock implements JobService {}

void main() {
  late MockJobService service;
  late JobProvider provider;

  final workDoneJob = Job(
    id: 'job-1',
    jobNumber: 'JOB-1',
    companyName: 'Doors Ltd',
    status: 'WORK_DONE',
    createdBy: 'manager-1',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    steps: [
      JobStep(
        id: 'step-1',
        stepName: 'Step 1',
        stepOrder: 1,
        status: JobStepStatus.completed,
      ),
    ],
  );

  setUp(() {
    service = MockJobService();
    provider = JobProvider(jobService: service);
    when(
      () => service.getManagerJob('job-1'),
    ).thenAnswer((_) async => workDoneJob);
  });

  test(
    'cancel updates the selected manager job and prevents a duplicate request',
    () async {
      final completer = Completer<Job>();
      when(
        () => service.cancelManagerJob('job-1'),
      ).thenAnswer((_) => completer.future);
      await provider.fetchManagerJob('job-1');

      final first = provider.cancelManagerJob('job-1');
      await provider.cancelManagerJob('job-1');

      expect(provider.managerCancelLoadingJobId, 'job-1');
      verify(() => service.cancelManagerJob('job-1')).called(1);

      final cancelled = _copyWithStatus(workDoneJob, 'CANCELLED');
      completer.complete(cancelled);
      await first;

      expect(provider.managerCancelLoadingJobId, isNull);
      expect(provider.managerSelectedJob?.status, 'CANCELLED');
    },
  );

  test(
    'reopen updates the selected manager job and preserves errors',
    () async {
      final reopened = _copyWithStatus(workDoneJob, 'IN_PROGRESS');
      when(
        () => service.reopenManagerJob('job-1', 'step-1'),
      ).thenAnswer((_) async => reopened);
      await provider.fetchManagerJob('job-1');

      await provider.reopenManagerJob('job-1', 'step-1');

      expect(provider.managerReopenLoadingJobId, isNull);
      expect(provider.managerReopenErrorMessage, isNull);
      expect(provider.managerSelectedJob?.status, 'IN_PROGRESS');

      when(
        () => service.reopenManagerJob('job-1', 'step-1'),
      ).thenThrow(Exception('Reopen failed'));
      await provider.reopenManagerJob('job-1', 'step-1');
      expect(provider.managerReopenErrorMessage, contains('Reopen failed'));
    },
  );

  test('cancel and reopen cannot run concurrently for the same job', () async {
    final completer = Completer<Job>();
    when(
      () => service.cancelManagerJob('job-1'),
    ).thenAnswer((_) => completer.future);

    final cancel = provider.cancelManagerJob('job-1');
    await provider.reopenManagerJob('job-1', 'step-1');

    verifyNever(() => service.reopenManagerJob(any(), any()));
    completer.complete(_copyWithStatus(workDoneJob, 'CANCELLED'));
    await cancel;
  });
}

Job _copyWithStatus(Job job, String status) => Job(
  id: job.id,
  jobNumber: job.jobNumber,
  companyName: job.companyName,
  status: status,
  chalanNumber: job.chalanNumber,
  createdBy: job.createdBy,
  createdAt: job.createdAt,
  updatedAt: job.updatedAt,
  completedAt: job.completedAt,
  steps: job.steps,
);
