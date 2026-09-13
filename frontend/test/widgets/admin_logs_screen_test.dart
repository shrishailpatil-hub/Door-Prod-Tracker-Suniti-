import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:frontend/models/job_step_history.dart';
import 'package:frontend/core/utils/file_export_helper.dart';
import 'package:frontend/providers/admin_log_provider.dart';
import 'package:frontend/screens/admin/admin_logs_screen.dart';

class MockAdminLogProvider extends Mock implements AdminLogProvider {}

class MockFileExportHelper extends Mock implements FileExportHelper {}

void main() {
  late MockAdminLogProvider mockProvider;
  late MockFileExportHelper mockFileExportHelper;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockProvider = MockAdminLogProvider();
    mockFileExportHelper = MockFileExportHelper();

    when(() => mockProvider.isLoading).thenReturn(false);
    when(() => mockProvider.logs).thenReturn([]);
    when(() => mockProvider.errorMessage).thenReturn(null);
    when(() => mockProvider.isExporting).thenReturn(false);
    when(() => mockProvider.exportErrorMessage).thenReturn(null);
    when(() => mockProvider.fetchLogs()).thenAnswer((_) async {});
    when(() => mockProvider.exportLogsExcel())
        .thenAnswer((_) async => Uint8List(10));
    when(() => mockFileExportHelper.saveExcelFile(bytes: any(named: 'bytes')))
        .thenAnswer((_) async => 'content://downloads/admin_audit.xlsx');
  });

  Widget buildTestWidget() {
    return ChangeNotifierProvider<AdminLogProvider>.value(
      value: mockProvider,
      child: MaterialApp(
        home: AdminLogsScreen(fileExportHelper: mockFileExportHelper),
      ),
    );
  }

  group('AdminLogsScreen Widget Tests', () {
    testWidgets('1. Shows loading indicator during initial load', (tester) async {
      when(() => mockProvider.isLoading).thenReturn(true);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('2. Shows empty state message when logs list is empty', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('No audit logs available'), findsOneWidget);
    });

    testWidgets('3. Renders loaded audit entries correctly', (tester) async {
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
      when(() => mockProvider.logs).thenReturn(logs);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Step Completed'), findsOneWidget);
      expect(find.text('Step: Cutting & Sizing'), findsOneWidget);
      expect(find.text('Job ID: job-101'), findsOneWidget);
      expect(find.text('By: Worker Bob'), findsOneWidget);
    });

    testWidgets('4. All five actions render correctly', (tester) async {
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
      when(() => mockProvider.logs).thenReturn(logs);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Step Completed'), findsOneWidget);
      expect(find.text('Step Undone'), findsOneWidget);
      expect(find.text('Step Reopened'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Job Completed'), 200.0);
      expect(find.text('Chalan Added'), findsOneWidget);
      expect(find.text('Job Completed'), findsOneWidget);
    });

    testWidgets('5. Shows error state and retry button triggers fetchLogs', (tester) async {
      when(() => mockProvider.errorMessage).thenReturn('Failed to load audit logs');

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Failed to load audit logs'), findsOneWidget);
      final retryButton = find.widgetWithText(ElevatedButton, 'Retry');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      verify(() => mockProvider.fetchLogs()).called(greaterThanOrEqualTo(1));
    });

    testWidgets('6. Pull-to-refresh triggers fetchLogs', (tester) async {
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
      when(() => mockProvider.logs).thenReturn(logs);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(ListView),
        const Offset(0.0, 300.0),
        1000.0,
      );
      await tester.pumpAndSettle();

      verify(() => mockProvider.fetchLogs()).called(greaterThanOrEqualTo(1));
    });

    testWidgets('7. Export saves Excel bytes and shows success SnackBar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final exportButton = find.byTooltip('Export Excel');
      expect(exportButton, findsOneWidget);

      await tester.tap(exportButton);
      await tester.pumpAndSettle();

      verify(() => mockProvider.exportLogsExcel()).called(1);
      verify(() => mockFileExportHelper.saveExcelFile(bytes: any(named: 'bytes'))).called(1);
      expect(find.text('Excel file exported successfully'), findsOneWidget);
    });

    testWidgets('8. Export loading state shows circular indicator in AppBar', (tester) async {
      when(() => mockProvider.isExporting).thenReturn(true);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byTooltip('Export Excel'), findsNothing);
    });

    testWidgets('9. Export error state shows error SnackBar', (tester) async {
      when(() => mockProvider.exportLogsExcel()).thenAnswer((_) async => null);
      when(() => mockProvider.exportErrorMessage).thenReturn('Server failed to generate export');

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final exportButton = find.byTooltip('Export Excel');
      await tester.tap(exportButton);
      await tester.pumpAndSettle();

      expect(find.text('Server failed to generate export'), findsOneWidget);
    });

    testWidgets('10. File save errors show safe export failure SnackBar', (tester) async {
      when(() => mockFileExportHelper.saveExcelFile(bytes: any(named: 'bytes')))
          .thenThrow(Exception('MediaStore failure'));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Export Excel'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to export Excel file'), findsOneWidget);
    });

    testWidgets('11. Rapid export taps trigger only one export request', (tester) async {
      final exportCompleter = Completer<Uint8List?>();
      when(() => mockProvider.exportLogsExcel()).thenAnswer((_) => exportCompleter.future);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final exportButton = find.byTooltip('Export Excel');
      await tester.tap(exportButton);
      await tester.tap(exportButton);
      await tester.pump();

      verify(() => mockProvider.exportLogsExcel()).called(1);

      exportCompleter.complete(Uint8List(10));
      await tester.pumpAndSettle();
    });
  });
}
