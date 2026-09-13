import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_router.dart';
import 'package:frontend/models/job.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/job_provider.dart';
import 'package:frontend/screens/manager/manager_create_job_screen.dart';
import 'package:frontend/screens/manager/manager_home_screen.dart';
import 'package:frontend/services/job_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockJobService extends Mock implements JobService {}

class MockAuthProvider extends Mock implements AuthProvider {}

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

  Widget buildCreateScreen() => ChangeNotifierProvider<JobProvider>.value(
    value: provider,
    child: const MaterialApp(home: ManagerCreateJobScreen()),
  );

  Future<void> fillValidForm(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('create-job-number-field')),
      '  JOB-900  ',
    );
    await tester.enterText(
      find.byKey(const Key('create-company-name-field')),
      '  Acme Doors  ',
    );
  }

  testWidgets('renders the manager create-job form', (tester) async {
    await tester.pumpWidget(buildCreateScreen());

    expect(find.text('Create Job'), findsNWidgets(2));
    expect(find.byKey(const Key('create-job-number-field')), findsOneWidget);
    expect(find.byKey(const Key('create-company-name-field')), findsOneWidget);
  });

  testWidgets('rejects empty and whitespace-only field values', (tester) async {
    await tester.pumpWidget(buildCreateScreen());

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Job'));
    await tester.pump();
    expect(find.text('Job Number is required.'), findsOneWidget);
    expect(find.text('Company Name is required.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('create-job-number-field')),
      '   ',
    );
    await tester.enterText(
      find.byKey(const Key('create-company-name-field')),
      '   ',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Job'));
    await tester.pump();
    expect(find.text('Job Number is required.'), findsOneWidget);
    expect(find.text('Company Name is required.'), findsOneWidget);
  });

  testWidgets('shows loading and prevents duplicate create submissions', (
    tester,
  ) async {
    final completer = Completer<Job>();
    when(
      () => service.createManagerJob(
        jobNumber: 'JOB-900',
        companyName: 'Acme Doors',
      ),
    ).thenAnswer((_) => completer.future);
    when(() => service.getManagerJobs()).thenAnswer((_) async => [createdJob]);
    await tester.pumpWidget(buildCreateScreen());
    await fillValidForm(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Job'));
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(provider.isCreatingManagerJob, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    verify(
      () => service.createManagerJob(
        jobNumber: 'JOB-900',
        companyName: 'Acme Doors',
      ),
    ).called(1);

    completer.complete(createdJob);
    await tester.pumpAndSettle();
  });

  testWidgets('shows backend and network errors from the provider', (
    tester,
  ) async {
    when(
      () => service.createManagerJob(
        jobNumber: 'JOB-900',
        companyName: 'Acme Doors',
      ),
    ).thenThrow(Exception('Job number already exists'));
    await tester.pumpWidget(buildCreateScreen());
    await fillValidForm(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Job'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Job number already exists'), findsOneWidget);

    when(
      () => service.createManagerJob(
        jobNumber: 'JOB-900',
        companyName: 'Acme Doors',
      ),
    ).thenThrow(Exception('Cannot reach server. Check your connection.'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Job'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cannot reach server'), findsOneWidget);
  });

  testWidgets('home navigation creates then refreshes the manager job list', (
    tester,
  ) async {
    var fetchCount = 0;
    when(() => service.getManagerJobs()).thenAnswer((_) async {
      fetchCount++;
      return fetchCount == 1 ? [] : [createdJob];
    });
    when(
      () => service.createManagerJob(
        jobNumber: 'JOB-900',
        companyName: 'Acme Doors',
      ),
    ).thenAnswer((_) async => createdJob);
    final auth = MockAuthProvider();
    when(() => auth.logout()).thenAnswer((_) async {});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<JobProvider>.value(value: provider),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: const MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: ManagerHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Create Job'));
    await tester.pumpAndSettle();
    expect(find.byType(ManagerCreateJobScreen), findsOneWidget);

    await fillValidForm(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Job'));
    await tester.pumpAndSettle();

    expect(find.text('JOB-900'), findsOneWidget);
    expect(find.text('Job created successfully.'), findsOneWidget);
    verify(() => service.getManagerJobs()).called(2);
  });
}
