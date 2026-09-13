// test/providers/job_provider_logs_test.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/models/job_step_history.dart';
import 'package:frontend/providers/job_provider.dart';
import 'package:frontend/services/job_service.dart';

class MockJobService extends Mock implements JobService {}

void main() {
  late MockJobService mockJobService;
  late JobProvider jobProvider;

  setUp(() {
    mockJobService = MockJobService();
    jobProvider = JobProvider(jobService: mockJobService);
  });

  group('JobProvider Logs & Export Tests', () {
    final sampleLogs = [
      JobStepHistory(
        id: 'h-1',
        jobId: 'j-1',
        jobStepId: 's-1',
        stepName: 'Cutting',
        action: JobStepAction.completed,
        performedBy: 'Worker Bob',
        createdAt: DateTime.parse('2026-09-09T10:00:00.000Z'),
      ),
    ];

    test(
      '8. fetchManagerLogs() success updates logs and resets loading/error state',
      () async {
        when(
          () => mockJobService.getManagerLogs(),
        ).thenAnswer((_) async => sampleLogs);

        expect(jobProvider.isManagerLogsLoading, isFalse);
        expect(jobProvider.managerAllLogs, isEmpty);
        expect(jobProvider.managerLogsErrorMessage, isNull);

        final future = jobProvider.fetchManagerLogs();
        expect(jobProvider.isManagerLogsLoading, isTrue);

        await future;

        expect(jobProvider.isManagerLogsLoading, isFalse);
        expect(jobProvider.managerAllLogs.length, 1);
        expect(jobProvider.managerAllLogs.first.stepName, 'Cutting');
        expect(jobProvider.managerLogsErrorMessage, isNull);
      },
    );

    test(
      '9. fetchManagerLogs() error sets error message and clears loading',
      () async {
        when(
          () => mockJobService.getManagerLogs(),
        ).thenThrow(Exception('Failed to load logs'));

        await jobProvider.fetchManagerLogs();

        expect(jobProvider.isManagerLogsLoading, isFalse);
        expect(jobProvider.managerAllLogs, isEmpty);
        expect(
          jobProvider.managerLogsErrorMessage,
          contains('Failed to load logs'),
        );
      },
    );

    test(
      '10. fetchManagerJobLogs() success updates job logs and resets loading/error state',
      () async {
        when(
          () => mockJobService.getManagerJobLogs('job-123'),
        ).thenAnswer((_) async => sampleLogs);

        expect(jobProvider.isManagerJobLogsLoading, isFalse);
        expect(jobProvider.managerJobLogs, isEmpty);
        expect(jobProvider.managerJobLogsErrorMessage, isNull);

        final future = jobProvider.fetchManagerJobLogs('job-123');
        expect(jobProvider.isManagerJobLogsLoading, isTrue);

        await future;

        expect(jobProvider.isManagerJobLogsLoading, isFalse);
        expect(jobProvider.managerJobLogs.length, 1);
        expect(jobProvider.managerJobLogs.first.jobId, 'j-1');
        expect(jobProvider.managerJobLogsErrorMessage, isNull);
      },
    );

    test(
      '11. fetchManagerJobLogs() error sets error message and clears loading',
      () async {
        when(
          () => mockJobService.getManagerJobLogs('job-123'),
        ).thenThrow(Exception('Job logs unavailable'));

        await jobProvider.fetchManagerJobLogs('job-123');

        expect(jobProvider.isManagerJobLogsLoading, isFalse);
        expect(jobProvider.managerJobLogs, isEmpty);
        expect(
          jobProvider.managerJobLogsErrorMessage,
          contains('Job logs unavailable'),
        );
      },
    );

    test('12, 13. Export loading state and success returning bytes', () async {
      final fakeBytes = Uint8List.fromList([1, 2, 3, 4]);
      when(
        () => mockJobService.exportManagerLogsExcel(),
      ).thenAnswer((_) async => fakeBytes);

      expect(jobProvider.isExportingExcel, isFalse);
      expect(jobProvider.exportErrorMessage, isNull);

      final future = jobProvider.exportManagerLogsExcel();
      expect(jobProvider.isExportingExcel, isTrue);

      final result = await future;

      expect(jobProvider.isExportingExcel, isFalse);
      expect(result, equals(fakeBytes));
      expect(jobProvider.exportErrorMessage, isNull);
    });

    test(
      '14. Export error sets error message, returns null, and resets loading',
      () async {
        when(
          () => mockJobService.exportManagerLogsExcel(),
        ).thenThrow(Exception('Export server error'));

        final result = await jobProvider.exportManagerLogsExcel();

        expect(jobProvider.isExportingExcel, isFalse);
        expect(result, isNull);
        expect(jobProvider.exportErrorMessage, contains('Export server error'));
      },
    );

    test(
      'export ignores a concurrent request while an export is in progress',
      () async {
        final completer = Completer<Uint8List>();
        when(
          () => mockJobService.exportManagerLogsExcel(),
        ).thenAnswer((_) => completer.future);

        final firstRequest = jobProvider.exportManagerLogsExcel();
        final duplicateRequest = await jobProvider.exportManagerLogsExcel();

        expect(duplicateRequest, isNull);
        verify(() => mockJobService.exportManagerLogsExcel()).called(1);

        completer.complete(Uint8List(1));
        await firstRequest;
      },
    );

    test('15. Previous errors are cleared when a new request begins', () async {
      // 1. Trigger an error first
      when(
        () => mockJobService.getManagerLogs(),
      ).thenThrow(Exception('First error'));
      await jobProvider.fetchManagerLogs();
      expect(jobProvider.managerLogsErrorMessage, isNotNull);

      // 2. Trigger new request that succeeds
      when(
        () => mockJobService.getManagerLogs(),
      ).thenAnswer((_) async => sampleLogs);
      final future = jobProvider.fetchManagerLogs();
      // While in-flight, the error should have been cleared
      expect(jobProvider.managerLogsErrorMessage, isNull);
      await future;
      expect(jobProvider.managerLogsErrorMessage, isNull);

      // Same check for export error clearing
      when(
        () => mockJobService.exportManagerLogsExcel(),
      ).thenThrow(Exception('Export error 1'));
      await jobProvider.exportManagerLogsExcel();
      expect(jobProvider.exportErrorMessage, isNotNull);

      when(
        () => mockJobService.exportManagerLogsExcel(),
      ).thenAnswer((_) async => Uint8List(0));
      final exportFuture = jobProvider.exportManagerLogsExcel();
      expect(jobProvider.exportErrorMessage, isNull);
      await exportFuture;
      expect(jobProvider.exportErrorMessage, isNull);
    });
  });
}
