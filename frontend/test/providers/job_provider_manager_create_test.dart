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
  late Job createdJob;

  setUp(() {
    service = MockJobService();
    provider = JobProvider(jobService: service);
    createdJob = Job(
      id: 'job-900',
      jobNumber: 'JOB-900',
      companyName: 'Acme Doors',
      status: 'IN_PROGRESS',
      createdBy: 'Manager Meera',
      createdAt: DateTime(2026, 9, 10),
      updatedAt: DateTime(2026, 9, 10),
      steps: const [],
    );
  });

  test(
    'creates a job and refreshes the manager list from the service',
    () async {
      when(
        () => service.createManagerJob(
          jobNumber: 'JOB-900',
          companyName: 'Acme Doors',
        ),
      ).thenAnswer((_) async => createdJob);
      when(
        () => service.getManagerJobs(),
      ).thenAnswer((_) async => [createdJob]);

      final result = await provider.createManagerJob(
        jobNumber: 'JOB-900',
        companyName: 'Acme Doors',
      );

      expect(result, createdJob);
      expect(provider.managerJobs, [createdJob]);
      expect(provider.isCreatingManagerJob, isFalse);
      expect(provider.managerCreateErrorMessage, isNull);
      verify(() => service.getManagerJobs()).called(1);
    },
  );

  test(
    'prevents a duplicate create request while the first is pending',
    () async {
      final createCompleter = Completer<Job>();
      when(
        () => service.createManagerJob(
          jobNumber: 'JOB-900',
          companyName: 'Acme Doors',
        ),
      ).thenAnswer((_) => createCompleter.future);
      when(
        () => service.getManagerJobs(),
      ).thenAnswer((_) async => [createdJob]);

      final first = provider.createManagerJob(
        jobNumber: 'JOB-900',
        companyName: 'Acme Doors',
      );
      final duplicate = await provider.createManagerJob(
        jobNumber: 'JOB-900',
        companyName: 'Acme Doors',
      );

      expect(duplicate, isNull);
      verify(
        () => service.createManagerJob(
          jobNumber: 'JOB-900',
          companyName: 'Acme Doors',
        ),
      ).called(1);

      createCompleter.complete(createdJob);
      await first;
    },
  );

  test('preserves the backend error for the create form', () async {
    when(
      () => service.createManagerJob(
        jobNumber: 'JOB-900',
        companyName: 'Acme Doors',
      ),
    ).thenThrow(Exception('Job number already exists'));

    final result = await provider.createManagerJob(
      jobNumber: 'JOB-900',
      companyName: 'Acme Doors',
    );

    expect(result, isNull);
    expect(provider.managerCreateErrorMessage, contains('already exists'));
  });
}
