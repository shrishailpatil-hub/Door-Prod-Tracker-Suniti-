// test/models/job_step_history_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/job_step_history.dart';

void main() {
  group('JobStepHistory Model Tests', () {
    test('Valid JSON deserializes correctly with all fields', () {
      final json = {
        'id': 'h-123',
        'jobId': 'job-456',
        'jobStepId': 'step-789',
        'stepName': 'Welding',
        'action': 'COMPLETED',
        'performedBy': 'Worker Bob',
        'createdAt': '2026-09-09T12:00:00.000Z',
      };

      final history = JobStepHistory.fromJson(json);

      expect(history.id, 'h-123');
      expect(history.jobId, 'job-456');
      expect(history.jobStepId, 'step-789');
      expect(history.stepName, 'Welding');
      expect(history.action, JobStepAction.completed);
      expect(history.performedBy, 'Worker Bob');
      expect(history.createdAt, DateTime.parse('2026-09-09T12:00:00.000Z'));
    });

    test(
      'All five JobStepAction values parse and convert to backend strings accurately',
      () {
        expect(
          JobStepActionExtension.fromString('COMPLETED'),
          JobStepAction.completed,
        );
        expect(
          JobStepActionExtension.fromString('UNDONE'),
          JobStepAction.undone,
        );
        expect(
          JobStepActionExtension.fromString('REOPENED'),
          JobStepAction.reopened,
        );
        expect(
          JobStepActionExtension.fromString('CHALAN_ADDED'),
          JobStepAction.chalanAdded,
        );
        expect(
          JobStepActionExtension.fromString('JOB_COMPLETED'),
          JobStepAction.jobCompleted,
        );

        expect(JobStepAction.completed.backendString, 'COMPLETED');
        expect(JobStepAction.undone.backendString, 'UNDONE');
        expect(JobStepAction.reopened.backendString, 'REOPENED');
        expect(JobStepAction.chalanAdded.backendString, 'CHALAN_ADDED');
        expect(JobStepAction.jobCompleted.backendString, 'JOB_COMPLETED');
      },
    );

    test('Null jobStepId and stepName are handled for job-level events', () {
      final json = {
        'id': 'h-chalan',
        'jobId': 'job-999',
        'jobStepId': null,
        'stepName': null,
        'action': 'CHALAN_ADDED',
        'performedBy': 'Worker Alice',
        'createdAt': '2026-09-09T14:30:00.000Z',
      };

      final history = JobStepHistory.fromJson(json);

      expect(history.id, 'h-chalan');
      expect(history.jobId, 'job-999');
      expect(history.jobStepId, isNull);
      expect(history.stepName, isNull);
      expect(history.action, JobStepAction.chalanAdded);
      expect(history.performedBy, 'Worker Alice');
      expect(history.createdAt, DateTime.parse('2026-09-09T14:30:00.000Z'));
    });

    test('createdAt parses ISO-8601 strings correctly', () {
      final json = {
        'id': 'h-job-done',
        'jobId': 'job-101',
        'jobStepId': null,
        'stepName': null,
        'action': 'JOB_COMPLETED',
        'performedBy': 'Worker Alice',
        'createdAt': '2026-01-15T08:15:30.123Z',
      };

      final history = JobStepHistory.fromJson(json);
      expect(history.createdAt.year, 2026);
      expect(history.createdAt.month, 1);
      expect(history.createdAt.day, 15);
      expect(history.createdAt.hour, 8);
      expect(history.createdAt.minute, 15);
      expect(history.createdAt.second, 30);
    });

    test('Throws ArgumentError on unknown JobStepAction', () {
      expect(
        () => JobStepActionExtension.fromString('UNKNOWN_ACTION'),
        throwsArgumentError,
      );
    });
  });
}
