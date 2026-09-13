import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/job.dart';
import 'package:frontend/providers/job_provider.dart';
import 'package:frontend/screens/manager/manager_job_detail_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockJobProvider extends Mock implements JobProvider {}

void main() {
  late MockJobProvider provider;

  setUp(() {
    provider = MockJobProvider();
    when(() => provider.isManagerDetailLoading).thenReturn(false);
    when(() => provider.managerDetailErrorMessage).thenReturn(null);
    when(() => provider.managerCancelLoadingJobId).thenReturn(null);
    when(() => provider.managerCancelErrorMessage).thenReturn(null);
    when(() => provider.managerReopenLoadingJobId).thenReturn(null);
    when(() => provider.managerReopenErrorMessage).thenReturn(null);
    when(() => provider.fetchManagerJob('job-1')).thenAnswer((_) async {});
    when(() => provider.cancelManagerJob('job-1')).thenAnswer((_) async {});
  });

  Job jobWithStatus(String status) => Job(
    id: 'job-1',
    jobNumber: 'JOB-1',
    companyName: 'Acme Doors',
    status: status,
    createdBy: 'Manager Meera',
    createdAt: DateTime(2026, 9, 10),
    updatedAt: DateTime(2026, 9, 10),
    steps: const [],
  );

  Future<void> pumpDetail(WidgetTester tester, String status) async {
    when(() => provider.managerSelectedJob).thenReturn(jobWithStatus(status));
    await tester.pumpWidget(
      ChangeNotifierProvider<JobProvider>.value(
        value: provider,
        child: const MaterialApp(home: ManagerJobDetailScreen(jobId: 'job-1')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows Cancel Job for an IN_PROGRESS job', (tester) async {
    await pumpDetail(tester, 'IN_PROGRESS');

    expect(find.widgetWithText(ElevatedButton, 'Cancel Job'), findsOneWidget);
  });

  testWidgets('hides Cancel Job for a WORK_DONE job', (tester) async {
    await pumpDetail(tester, 'WORK_DONE');

    expect(find.text('Cancel Job'), findsNothing);
  });

  testWidgets('hides Cancel Job for a JOB_COMPLETED job', (tester) async {
    await pumpDetail(tester, 'JOB_COMPLETED');

    expect(find.text('Cancel Job'), findsNothing);
  });

  testWidgets('hides Cancel Job for a CANCELLED job', (tester) async {
    await pumpDetail(tester, 'CANCELLED');

    expect(find.text('Cancel Job'), findsNothing);
  });

  testWidgets(
    'confirms and invokes the existing cancel action for IN_PROGRESS',
    (tester) async {
      await pumpDetail(tester, 'IN_PROGRESS');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel Job'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel Job?'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel Job').last);
      await tester.pumpAndSettle();

      verify(() => provider.cancelManagerJob('job-1')).called(1);
    },
  );
}
