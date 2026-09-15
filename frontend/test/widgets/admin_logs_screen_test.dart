import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:frontend/models/job.dart';
import 'package:frontend/core/utils/file_export_helper.dart';
import 'package:frontend/providers/admin_log_provider.dart';
import 'package:frontend/providers/job_provider.dart';
import 'package:frontend/screens/admin/admin_logs_screen.dart';
import 'package:frontend/screens/admin/admin_job_logs_screen.dart';

class MockAdminLogProvider extends Mock implements AdminLogProvider {}
class MockJobProvider extends Mock implements JobProvider {}
class MockFileExportHelper extends Mock implements FileExportHelper {}

void main() {
  late MockAdminLogProvider mockAdminLogProvider;
  late MockJobProvider mockJobProvider;
  late MockFileExportHelper mockFileExportHelper;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockAdminLogProvider = MockAdminLogProvider();
    mockJobProvider = MockJobProvider();
    mockFileExportHelper = MockFileExportHelper();

    when(() => mockJobProvider.isManagerLoading).thenReturn(false);
    when(() => mockJobProvider.managerJobs).thenReturn([]);
    when(() => mockJobProvider.managerErrorMessage).thenReturn(null);
    when(() => mockJobProvider.fetchManagerJobs()).thenAnswer((_) async {});
    when(() => mockJobProvider.isManagerJobLogsLoading).thenReturn(false);
    when(() => mockJobProvider.managerJobLogs).thenReturn([]);
    when(() => mockJobProvider.managerJobLogsErrorMessage).thenReturn(null);
    when(() => mockJobProvider.fetchManagerJobLogs(any())).thenAnswer((_) async {});

    when(() => mockAdminLogProvider.isExporting).thenReturn(false);
    when(() => mockAdminLogProvider.exportErrorMessage).thenReturn(null);
    when(() => mockAdminLogProvider.exportLogsExcel())
        .thenAnswer((_) async => Uint8List(10));
    when(() => mockFileExportHelper.saveExcelFile(bytes: any(named: 'bytes')))
        .thenAnswer((_) async => 'content://downloads/admin_audit.xlsx');
  });

  Widget buildTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AdminLogProvider>.value(value: mockAdminLogProvider),
        ChangeNotifierProvider<JobProvider>.value(value: mockJobProvider),
      ],
      child: MaterialApp(
        home: AdminLogsScreen(fileExportHelper: mockFileExportHelper),
      ),
    );
  }

  Job createTestJob({
    required String id,
    required String jobNumber,
    required String companyName,
    required String status,
  }) {
    return Job(
      id: id,
      jobNumber: jobNumber,
      companyName: companyName,
      status: status,
      createdBy: 'Admin',
      createdAt: DateTime.parse('2026-09-09T10:00:00.000Z'),
      updatedAt: DateTime.parse('2026-09-09T10:00:00.000Z'),
      steps: [],
    );
  }

  group('AdminLogsScreen Widget Tests', () {
    testWidgets('1. Shows loading indicator during initial jobs load', (tester) async {
      when(() => mockJobProvider.isManagerLoading).thenReturn(true);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('2. Shows empty state message when active jobs list is empty', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('No active jobs available'), findsOneWidget);
    });

    testWidgets('3. Renders only active jobs, filtering out COMPLETED and completed case-insensitively', (tester) async {
      final jobs = [
        createTestJob(id: 'j-1', jobNumber: 'JOB-101', companyName: 'Acme Doors', status: 'IN_PROGRESS'),
        createTestJob(id: 'j-2', jobNumber: 'JOB-102', companyName: 'Beta Windows', status: 'WORK_DONE'),
        createTestJob(id: 'j-3', jobNumber: 'JOB-103', companyName: 'Completed Corp', status: 'COMPLETED'),
        createTestJob(id: 'j-4', jobNumber: 'JOB-104', companyName: 'Lower Completed', status: 'completed'),
      ];
      when(() => mockJobProvider.managerJobs).thenReturn(jobs);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Job JOB-101'), findsOneWidget);
      expect(find.text('Company: Acme Doors'), findsOneWidget);
      expect(find.text('Job JOB-102'), findsOneWidget);
      expect(find.text('Company: Beta Windows'), findsOneWidget);

      expect(find.text('Job JOB-103'), findsNothing);
      expect(find.text('Company: Completed Corp'), findsNothing);
      expect(find.text('Job JOB-104'), findsNothing);
    });

    testWidgets('4. Tapping an active job navigates to AdminJobLogsScreen with job ID', (tester) async {
      final jobs = [
        createTestJob(id: 'job-999', jobNumber: 'JOB-999', companyName: 'Gamma Entry', status: 'IN_PROGRESS'),
      ];
      when(() => mockJobProvider.managerJobs).thenReturn(jobs);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Job JOB-999'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminJobLogsScreen), findsOneWidget);
      expect(find.text('Job History'), findsOneWidget);
      verify(() => mockJobProvider.fetchManagerJobLogs('job-999')).called(1);
    });

    testWidgets('5. Shows error state and retry button triggers fetchManagerJobs', (tester) async {
      when(() => mockJobProvider.managerErrorMessage).thenReturn('Failed to load jobs');

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Failed to load jobs'), findsOneWidget);
      final retryButton = find.widgetWithText(ElevatedButton, 'Retry');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      verify(() => mockJobProvider.fetchManagerJobs()).called(greaterThanOrEqualTo(1));
    });

    testWidgets('6. Pull-to-refresh triggers fetchManagerJobs', (tester) async {
      final jobs = [
        createTestJob(id: 'j-1', jobNumber: 'JOB-101', companyName: 'Acme', status: 'IN_PROGRESS'),
      ];
      when(() => mockJobProvider.managerJobs).thenReturn(jobs);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(ListView),
        const Offset(0.0, 300.0),
        1000.0,
      );
      await tester.pumpAndSettle();

      verify(() => mockJobProvider.fetchManagerJobs()).called(greaterThanOrEqualTo(1));
    });

    testWidgets('7. Export saves Excel bytes and shows success SnackBar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final exportButton = find.byTooltip('Export Excel');
      expect(exportButton, findsOneWidget);

      await tester.tap(exportButton);
      await tester.pumpAndSettle();

      verify(() => mockAdminLogProvider.exportLogsExcel()).called(1);
      verify(() => mockFileExportHelper.saveExcelFile(bytes: any(named: 'bytes'))).called(1);
      expect(find.text('Excel file exported successfully'), findsOneWidget);
    });

    testWidgets('8. Export loading state shows circular indicator in AppBar', (tester) async {
      when(() => mockAdminLogProvider.isExporting).thenReturn(true);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byTooltip('Export Excel'), findsNothing);
    });

    testWidgets('9. Export error state shows error SnackBar', (tester) async {
      when(() => mockAdminLogProvider.exportLogsExcel()).thenAnswer((_) async => null);
      when(() => mockAdminLogProvider.exportErrorMessage).thenReturn('Server failed to generate export');

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
      when(() => mockAdminLogProvider.exportLogsExcel()).thenAnswer((_) => exportCompleter.future);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final exportButton = find.byTooltip('Export Excel');
      await tester.tap(exportButton);
      await tester.tap(exportButton);
      await tester.pump();

      verify(() => mockAdminLogProvider.exportLogsExcel()).called(1);

      exportCompleter.complete(Uint8List(10));
      await tester.pumpAndSettle();
    });
  });
}

