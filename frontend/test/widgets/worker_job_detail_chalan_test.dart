// test/widgets/worker_job_detail_chalan_test.dart
//
// Tests that the Challan field enables/disables the Save button
// reactively based on the text the user types.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:frontend/models/job.dart';
import 'package:frontend/providers/job_provider.dart';
import 'package:frontend/screens/worker/worker_job_detail_screen.dart';

class MockJobProvider extends Mock implements JobProvider {}

void main() {
  late MockJobProvider mockJobProvider;

  /// A WORK_DONE job with no chalan number saved yet.
  Job makeWorkDoneJob({String? chalanNumber}) => Job(
        id: 'j1',
        jobNumber: 'JOB-100',
        companyName: 'Acme Corp',
        status: 'WORK_DONE',
        chalanNumber: chalanNumber,
        createdBy: 'manager1',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        completedAt: null,
        steps: [
          JobStep(
            id: 's1',
            stepName: 'Cutting',
            stepOrder: 1,
            status: JobStepStatus.completed,
          ),
        ],
      );

  Widget buildTestWidget() {
    return ChangeNotifierProvider<JobProvider>.value(
      value: mockJobProvider,
      child: MaterialApp(
        home: SizedBox(
          // Use a tall surface so ListView items are not lazy-clipped
          height: 1200,
          child: const WorkerJobDetailScreen(jobId: 'j1'),
        ),
      ),
    );
  }

  setUp(() {
    mockJobProvider = MockJobProvider();

    // Default stubs — all properties the Consumer reads
    when(() => mockJobProvider.isDetailLoading).thenReturn(false);
    when(() => mockJobProvider.selectedJob).thenReturn(null);
    when(() => mockJobProvider.detailErrorMessage).thenReturn(null);
    when(() => mockJobProvider.stepActionError).thenReturn(null);
    when(() => mockJobProvider.actionError).thenReturn(null);
    when(() => mockJobProvider.actionLoadingStepId).thenReturn(null);
    when(() => mockJobProvider.actionLoadingJobId).thenReturn(null);
    when(() => mockJobProvider.fetchJobDetail(any())).thenAnswer((_) async {});
    when(() => mockJobProvider.clearSelectedJob()).thenReturn(null);
    when(() => mockJobProvider.clearStepActionError()).thenReturn(null);
    when(() => mockJobProvider.clearActionError()).thenReturn(null);
  });

  group('Challan field reactive Save button', () {
    testWidgets(
        'Save Chalan is disabled when challan field is empty (no saved value)',
        (WidgetTester tester) async {
      final job = makeWorkDoneJob(chalanNumber: null);
      when(() => mockJobProvider.selectedJob).thenReturn(job);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(); // post-frame callback
      await tester.pump(); // rebuild after fetchJobDetail

      // Scroll down to ensure the Save Chalan button is visible
      await tester.scrollUntilVisible(
        find.text('Save Chalan'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      // The Save Chalan button should exist but be disabled
      final saveFinder = find.widgetWithText(ElevatedButton, 'Save Chalan');
      expect(saveFinder, findsOneWidget);

      final ElevatedButton button = tester.widget<ElevatedButton>(saveFinder);
      expect(button.onPressed, isNull,
          reason: 'Save should be disabled when field is empty');
    });

    testWidgets(
        'Save Chalan becomes enabled when user types a value',
        (WidgetTester tester) async {
      final job = makeWorkDoneJob(chalanNumber: null);
      when(() => mockJobProvider.selectedJob).thenReturn(job);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      // Scroll to make the TextField and Save button visible
      await tester.scrollUntilVisible(
        find.text('Save Chalan'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      // Find the TextField and type a challan number
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      await tester.enterText(textFieldFinder, '12345');
      await tester.pump();

      final ElevatedButton button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Save Chalan'),
      );
      expect(button.onPressed, isNotNull,
          reason: 'Save should be enabled after typing a value');
    });

    testWidgets(
        'Save Chalan becomes disabled again when user clears the field',
        (WidgetTester tester) async {
      final job = makeWorkDoneJob(chalanNumber: null);
      when(() => mockJobProvider.selectedJob).thenReturn(job);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      // Scroll to make the TextField visible
      await tester.scrollUntilVisible(
        find.text('Save Chalan'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      final textFieldFinder = find.byType(TextField);

      // Type a value
      await tester.enterText(textFieldFinder, '12345');
      await tester.pump();

      // Verify enabled
      ElevatedButton button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Save Chalan'),
      );
      expect(button.onPressed, isNotNull);

      // Clear the field
      await tester.enterText(textFieldFinder, '');
      await tester.pump();

      // Verify disabled again
      button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Save Chalan'),
      );
      expect(button.onPressed, isNull,
          reason: 'Save should be disabled when field is cleared');
    });

    testWidgets(
        'Save Chalan is disabled when challan is already saved',
        (WidgetTester tester) async {
      final job = makeWorkDoneJob(chalanNumber: 'SAVED-999');
      when(() => mockJobProvider.selectedJob).thenReturn(job);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      // Scroll to the Save Chalan button
      await tester.scrollUntilVisible(
        find.text('Save Chalan'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      // The Save button should exist but be disabled because chalanNumber
      // is already set (non-null, non-empty).
      final saveFinder = find.widgetWithText(ElevatedButton, 'Save Chalan');
      expect(saveFinder, findsOneWidget);

      final ElevatedButton button = tester.widget<ElevatedButton>(saveFinder);
      expect(button.onPressed, isNull,
          reason: 'Save should be disabled when challan is already saved');
    });
  });
}
