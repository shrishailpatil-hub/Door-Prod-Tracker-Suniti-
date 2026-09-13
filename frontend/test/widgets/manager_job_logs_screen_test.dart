// test/widgets/manager_job_logs_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:frontend/models/job_step_history.dart';
import 'package:frontend/providers/job_provider.dart';
import 'package:frontend/screens/manager/manager_job_logs_screen.dart';

class MockJobProvider extends Mock implements JobProvider {}

void main() {
  late MockJobProvider mockJobProvider;

  setUp(() {
    mockJobProvider = MockJobProvider();
    when(() => mockJobProvider.isManagerJobLogsLoading).thenReturn(false);
    when(() => mockJobProvider.managerJobLogs).thenReturn([]);
    when(() => mockJobProvider.managerJobLogsErrorMessage).thenReturn(null);
    when(
      () => mockJobProvider.fetchManagerJobLogs(any()),
    ).thenAnswer((_) async {});
  });

  Widget buildTestWidget({String jobId = 'test-job-42'}) {
    return ChangeNotifierProvider<JobProvider>.value(
      value: mockJobProvider,
      child: MaterialApp(home: ManagerJobLogsScreen(jobId: jobId)),
    );
  }

  group('ManagerJobLogsScreen Widget Tests', () {
    testWidgets(
      '13. Shows loading indicator when job logs are loading and list is empty',
      (tester) async {
        when(() => mockJobProvider.isManagerJobLogsLoading).thenReturn(true);

        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      '14. Loaded history renders step, performer, and action correctly',
      (tester) async {
        final logs = [
          JobStepHistory(
            id: 'log-1',
            jobId: 'test-job-42',
            jobStepId: 'step-1',
            stepName: 'Powder Coating',
            action: JobStepAction.completed,
            performedBy: 'Painter Dave',
            createdAt: DateTime.parse('2026-09-09T14:00:00.000Z'),
          ),
        ];
        when(() => mockJobProvider.managerJobLogs).thenReturn(logs);

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Step Completed'), findsOneWidget);
        expect(find.text('Step: Powder Coating'), findsOneWidget);
        expect(find.text('By: Painter Dave'), findsOneWidget);
      },
    );

    testWidgets('15. Shows empty state when job has no history', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('No history for this job'), findsOneWidget);
    });

    testWidgets(
      '16, 17. Shows error state and retry triggers fetchManagerJobLogs',
      (tester) async {
        when(
          () => mockJobProvider.managerJobLogsErrorMessage,
        ).thenReturn('Failed to load job logs');

        await tester.pumpWidget(buildTestWidget(jobId: 'job-99'));
        await tester.pumpAndSettle();

        expect(find.text('Failed to load job logs'), findsOneWidget);
        final retryButton = find.widgetWithText(ElevatedButton, 'Retry');
        expect(retryButton, findsOneWidget);

        await tester.tap(retryButton);
        verify(
          () => mockJobProvider.fetchManagerJobLogs('job-99'),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    testWidgets(
      '18, 19. All five actions and job-level events with null step render without error',
      (tester) async {
        final logs = [
          JobStepHistory(
            id: 'l-1',
            jobId: 'job-42',
            jobStepId: 's-1',
            stepName: 'Cut',
            action: JobStepAction.completed,
            performedBy: 'Worker 1',
            createdAt: DateTime.parse('2026-09-09T09:00:00.000Z'),
          ),
          JobStepHistory(
            id: 'l-2',
            jobId: 'job-42',
            jobStepId: 's-1',
            stepName: 'Cut',
            action: JobStepAction.undone,
            performedBy: 'Worker 1',
            createdAt: DateTime.parse('2026-09-09T09:05:00.000Z'),
          ),
          JobStepHistory(
            id: 'l-3',
            jobId: 'job-42',
            jobStepId: 's-1',
            stepName: 'Cut',
            action: JobStepAction.reopened,
            performedBy: 'Manager A',
            createdAt: DateTime.parse('2026-09-09T09:10:00.000Z'),
          ),
          JobStepHistory(
            id: 'l-4',
            jobId: 'job-42',
            jobStepId: null,
            stepName: null,
            action: JobStepAction.chalanAdded,
            performedBy: 'Worker 2',
            createdAt: DateTime.parse('2026-09-09T09:15:00.000Z'),
          ),
          JobStepHistory(
            id: 'l-5',
            jobId: 'job-42',
            jobStepId: null,
            stepName: null,
            action: JobStepAction.jobCompleted,
            performedBy: 'Worker 2',
            createdAt: DateTime.parse('2026-09-09T09:20:00.000Z'),
          ),
        ];
        when(() => mockJobProvider.managerJobLogs).thenReturn(logs);

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Step Completed'), findsOneWidget);
        expect(find.text('Step Undone'), findsOneWidget);
        expect(find.text('Step Reopened'), findsOneWidget);
        expect(find.text('Chalan Added'), findsOneWidget);
        expect(find.text('Job Completed'), findsOneWidget);
      },
    );
  });
}
