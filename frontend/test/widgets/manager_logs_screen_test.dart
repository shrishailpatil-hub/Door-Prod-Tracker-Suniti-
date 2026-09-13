// test/widgets/manager_logs_screen_test.dart

import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:frontend/models/job_step_history.dart';
import 'package:frontend/core/utils/file_export_helper.dart';
import 'package:frontend/providers/job_provider.dart';
import 'package:frontend/screens/manager/manager_logs_screen.dart';

class MockJobProvider extends Mock implements JobProvider {}

class MockFileExportHelper extends Mock implements FileExportHelper {}

void main() {
  late MockJobProvider mockJobProvider;
  late MockFileExportHelper mockFileExportHelper;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockJobProvider = MockJobProvider();
    mockFileExportHelper = MockFileExportHelper();
    when(() => mockJobProvider.isManagerLogsLoading).thenReturn(false);
    when(() => mockJobProvider.managerAllLogs).thenReturn([]);
    when(() => mockJobProvider.managerLogsErrorMessage).thenReturn(null);
    when(() => mockJobProvider.isExportingExcel).thenReturn(false);
    when(() => mockJobProvider.exportErrorMessage).thenReturn(null);
    when(() => mockJobProvider.fetchManagerLogs()).thenAnswer((_) async {});
    when(
      () => mockJobProvider.exportManagerLogsExcel(),
    ).thenAnswer((_) async => Uint8List(10));
    when(
      () => mockFileExportHelper.saveExcelFile(bytes: any(named: 'bytes')),
    ).thenAnswer((_) async => 'content://downloads/audit.xlsx');
  });

  Widget buildTestWidget() {
    return ChangeNotifierProvider<JobProvider>.value(
      value: mockJobProvider,
      child: MaterialApp(
        home: ManagerLogsScreen(fileExportHelper: mockFileExportHelper),
      ),
    );
  }

  group('ManagerLogsScreen Widget Tests', () {
    testWidgets(
      '1. Shows loading indicator when logs are loading and list is empty',
      (tester) async {
        when(() => mockJobProvider.isManagerLogsLoading).thenReturn(true);

        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets('2. Shows empty state message when logs list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('No audit logs available'), findsOneWidget);
    });

    testWidgets(
      '3. Renders loaded audit entries with step, job ID, performer, timestamp',
      (tester) async {
        final logs = [
          JobStepHistory(
            id: 'log-1',
            jobId: 'job-101',
            jobStepId: 'step-1',
            stepName: 'Cutting & Sizing',
            action: JobStepAction.completed,
            performedBy: 'Worker Bob',
            createdAt: DateTime.parse('2026-09-09T10:30:00.000Z'),
          ),
        ];
        when(() => mockJobProvider.managerAllLogs).thenReturn(logs);

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Step Completed'), findsOneWidget);
        expect(find.text('Step: Cutting & Sizing'), findsOneWidget);
        expect(find.text('Job ID: job-101'), findsOneWidget);
        expect(find.text('By: Worker Bob'), findsOneWidget);
      },
    );

    testWidgets(
      '4, 5. All five actions and null step/jobStepId render correctly without crashing',
      (tester) async {
        final logs = [
          JobStepHistory(
            id: 'log-1',
            jobId: 'j-1',
            jobStepId: 's-1',
            stepName: 'Welding',
            action: JobStepAction.completed,
            performedBy: 'Worker 1',
            createdAt: DateTime.parse('2026-09-09T10:00:00.000Z'),
          ),
          JobStepHistory(
            id: 'log-2',
            jobId: 'j-2',
            jobStepId: 's-2',
            stepName: 'Welding',
            action: JobStepAction.undone,
            performedBy: 'Worker 2',
            createdAt: DateTime.parse('2026-09-09T10:05:00.000Z'),
          ),
          JobStepHistory(
            id: 'log-3',
            jobId: 'j-3',
            jobStepId: 's-3',
            stepName: 'Bending',
            action: JobStepAction.reopened,
            performedBy: 'Manager Alice',
            createdAt: DateTime.parse('2026-09-09T10:10:00.000Z'),
          ),
          JobStepHistory(
            id: 'log-4',
            jobId: 'j-4',
            jobStepId: null,
            stepName: null,
            action: JobStepAction.chalanAdded,
            performedBy: 'Worker 3',
            createdAt: DateTime.parse('2026-09-09T10:15:00.000Z'),
          ),
          JobStepHistory(
            id: 'log-5',
            jobId: 'j-5',
            jobStepId: null,
            stepName: null,
            action: JobStepAction.jobCompleted,
            performedBy: 'Worker 4',
            createdAt: DateTime.parse('2026-09-09T10:20:00.000Z'),
          ),
        ];
        when(() => mockJobProvider.managerAllLogs).thenReturn(logs);

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Step Completed'), findsOneWidget);
        expect(find.text('Step Undone'), findsOneWidget);
        expect(find.text('Step Reopened'), findsOneWidget);

        await tester.scrollUntilVisible(find.text('Job Completed'), 200.0);
        expect(find.text('Chalan Added'), findsOneWidget);
        expect(find.text('Job Completed'), findsOneWidget);
      },
    );

    testWidgets(
      '6, 7. Shows error state and retry button triggers fetchManagerLogs',
      (tester) async {
        when(
          () => mockJobProvider.managerLogsErrorMessage,
        ).thenReturn('Network error loading logs');

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Network error loading logs'), findsOneWidget);
        final retryButton = find.widgetWithText(ElevatedButton, 'Retry');
        expect(retryButton, findsOneWidget);

        await tester.tap(retryButton);
        verify(
          () => mockJobProvider.fetchManagerLogs(),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    testWidgets('8. Pull-to-refresh triggers fetchManagerLogs', (tester) async {
      final logs = [
        JobStepHistory(
          id: 'log-1',
          jobId: 'j-1',
          stepName: 'Cut',
          action: JobStepAction.completed,
          performedBy: 'Worker 1',
          createdAt: DateTime.parse('2026-09-09T10:00:00.000Z'),
        ),
      ];
      when(() => mockJobProvider.managerAllLogs).thenReturn(logs);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(ListView),
        const Offset(0.0, 300.0),
        1000.0,
      );
      await tester.pumpAndSettle();

      verify(
        () => mockJobProvider.fetchManagerLogs(),
      ).called(greaterThanOrEqualTo(1));
    });

    testWidgets('9, 12. Export saves Excel bytes and shows success SnackBar', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final exportButton = find.byTooltip('Export Excel');
      expect(exportButton, findsOneWidget);

      await tester.tap(exportButton);
      await tester.pumpAndSettle();

      verify(() => mockJobProvider.exportManagerLogsExcel()).called(1);
      verify(
        () => mockFileExportHelper.saveExcelFile(bytes: any(named: 'bytes')),
      ).called(1);
      expect(find.text('Excel file exported successfully'), findsOneWidget);
    });

    testWidgets('10. Export loading state shows circular indicator in AppBar', (
      tester,
    ) async {
      when(() => mockJobProvider.isExportingExcel).thenReturn(true);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byTooltip('Export Excel'), findsNothing);
    });

    testWidgets('11. Export error state shows error SnackBar', (tester) async {
      when(
        () => mockJobProvider.exportManagerLogsExcel(),
      ).thenAnswer((_) async => null);
      when(
        () => mockJobProvider.exportErrorMessage,
      ).thenReturn('Server failed to generate export');

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final exportButton = find.byTooltip('Export Excel');
      await tester.tap(exportButton);
      await tester.pumpAndSettle();

      expect(find.text('Server failed to generate export'), findsOneWidget);
    });

    testWidgets('file save errors show a safe export failure SnackBar', (
      tester,
    ) async {
      when(
        () => mockFileExportHelper.saveExcelFile(bytes: any(named: 'bytes')),
      ).thenThrow(Exception('MediaStore failure'));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Export Excel'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to export Excel file'), findsOneWidget);
    });

    testWidgets('rapid export taps trigger only one export request', (
      tester,
    ) async {
      final exportCompleter = Completer<Uint8List?>();
      when(
        () => mockJobProvider.exportManagerLogsExcel(),
      ).thenAnswer((_) => exportCompleter.future);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final exportButton = find.byTooltip('Export Excel');
      await tester.tap(exportButton);
      await tester.tap(exportButton);
      await tester.pump();

      verify(() => mockJobProvider.exportManagerLogsExcel()).called(1);

      exportCompleter.complete(Uint8List(10));
      await tester.pumpAndSettle();
    });
  });
}
