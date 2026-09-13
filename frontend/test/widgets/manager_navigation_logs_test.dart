// test/widgets/manager_navigation_logs_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/config/app_router.dart';
import 'package:frontend/models/job.dart';
import 'package:frontend/models/auth/user_role.dart';
import 'package:frontend/models/auth/user_session.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/job_provider.dart';
import 'package:frontend/screens/manager/manager_home_screen.dart';
import 'package:frontend/screens/manager/manager_job_detail_screen.dart';

class MockJobProvider extends Mock implements JobProvider {}

class MockAuthProvider extends Mock implements AuthProvider {}

class FakeUserSession extends UserSession {
  FakeUserSession({
    required String userId,
    required String name,
    required UserRole role,
  }) : super(token: 'dummy-token', userId: userId, name: name, role: role);
}

void main() {
  late MockJobProvider mockJobProvider;
  late MockAuthProvider mockAuthProvider;

  setUp(() {
    mockJobProvider = MockJobProvider();
    mockAuthProvider = MockAuthProvider();

    when(() => mockAuthProvider.isInitialized).thenReturn(true);
    when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
    when(() => mockAuthProvider.session).thenReturn(
      FakeUserSession(
        userId: 'm-1',
        name: 'Manager Alice',
        role: UserRole.manager,
      ),
    );

    when(() => mockJobProvider.isManagerLoading).thenReturn(false);
    when(() => mockJobProvider.managerJobs).thenReturn([]);
    when(() => mockJobProvider.managerErrorMessage).thenReturn(null);
    when(() => mockJobProvider.fetchManagerJobs()).thenAnswer((_) async {});
    when(() => mockJobProvider.isCreatingManagerJob).thenReturn(false);
    when(() => mockJobProvider.managerCreateErrorMessage).thenReturn(null);

    when(() => mockJobProvider.isManagerLogsLoading).thenReturn(false);
    when(() => mockJobProvider.managerAllLogs).thenReturn([]);
    when(() => mockJobProvider.managerLogsErrorMessage).thenReturn(null);
    when(() => mockJobProvider.fetchManagerLogs()).thenAnswer((_) async {});
    when(() => mockJobProvider.isExportingExcel).thenReturn(false);
    when(() => mockJobProvider.exportErrorMessage).thenReturn(null);

    when(() => mockJobProvider.isManagerJobLogsLoading).thenReturn(false);
    when(() => mockJobProvider.managerJobLogs).thenReturn([]);
    when(() => mockJobProvider.managerJobLogsErrorMessage).thenReturn(null);
    when(
      () => mockJobProvider.fetchManagerJobLogs(any()),
    ).thenAnswer((_) async {});
  });

  Widget buildManagerHome() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<JobProvider>.value(value: mockJobProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
      ],
      child: const MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: ManagerHomeScreen(),
      ),
    );
  }

  Widget buildManagerHomeFromRoute() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<JobProvider>.value(value: mockJobProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
      ],
      child: const MaterialApp(
        initialRoute: AppRouter.managerHome,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }

  Widget buildManagerJobDetail(String jobId) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<JobProvider>.value(value: mockJobProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
      ],
      child: MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: ManagerJobDetailScreen(jobId: jobId),
      ),
    );
  }

  group('Manager Navigation to Logs Tests', () {
    testWidgets('manager home route renders the Manager dashboard', (
      tester,
    ) async {
      await tester.pumpWidget(buildManagerHomeFromRoute());
      await tester.pumpAndSettle();

      expect(find.text('Manager Dashboard'), findsOneWidget);
      verify(() => mockJobProvider.fetchManagerJobs()).called(1);
    });

    testWidgets(
      '20. ManagerHomeScreen Audit Logs action navigates to /manager/logs',
      (tester) async {
        await tester.pumpWidget(buildManagerHome());
        await tester.pumpAndSettle();

        final auditButton = find.byTooltip('Audit Logs');
        expect(auditButton, findsOneWidget);

        await tester.tap(auditButton);
        await tester.pumpAndSettle();

        // ManagerLogsScreen should be pushed
        expect(find.text('Audit Logs'), findsWidgets);
        verify(
          () => mockJobProvider.fetchManagerLogs(),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    testWidgets(
      '21. ManagerJobDetailScreen View Job History navigates to /manager/jobs/:jobId/logs',
      (tester) async {
        final sampleJob = Job(
          id: 'job-xyz-789',
          jobNumber: 'JOB-789',
          companyName: 'Acme Doors',
          status: 'IN_PROGRESS',
          createdBy: 'Manager Alice',
          createdAt: DateTime.parse('2026-09-09T08:00:00.000Z'),
          updatedAt: DateTime.parse('2026-09-09T08:00:00.000Z'),
          steps: [],
        );
        when(() => mockJobProvider.isManagerDetailLoading).thenReturn(false);
        when(() => mockJobProvider.managerSelectedJob).thenReturn(sampleJob);
        when(() => mockJobProvider.managerDetailErrorMessage).thenReturn(null);
        when(
          () => mockJobProvider.fetchManagerJob('job-xyz-789'),
        ).thenAnswer((_) async {});
        when(() => mockJobProvider.managerCancelLoadingJobId).thenReturn(null);
        when(() => mockJobProvider.managerCancelErrorMessage).thenReturn(null);
        when(() => mockJobProvider.managerReopenLoadingJobId).thenReturn(null);
        when(() => mockJobProvider.managerReopenErrorMessage).thenReturn(null);

        await tester.pumpWidget(buildManagerJobDetail('job-xyz-789'));
        await tester.pumpAndSettle();

        final historyButton = find.widgetWithText(
          OutlinedButton,
          'View Job History',
        );
        expect(historyButton, findsOneWidget);

        await tester.tap(historyButton);
        await tester.pumpAndSettle();

        // ManagerJobLogsScreen should be pushed
        expect(find.text('Job History'), findsOneWidget);
        verify(
          () => mockJobProvider.fetchManagerJobLogs('job-xyz-789'),
        ).called(1);
      },
    );
  });
}
