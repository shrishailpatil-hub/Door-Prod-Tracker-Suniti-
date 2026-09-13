// test/widgets/worker_home_screen_test.dart

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
import 'package:frontend/screens/worker/worker_home_screen.dart';

class MockJobProvider extends Mock implements JobProvider {}

class MockAuthProvider extends Mock implements AuthProvider {}

// Define a fake user session that extends the real UserSession model
class FakeUserSession extends UserSession {
  FakeUserSession({
    required String userId,
    required String name,
    required UserRole role,
  }) : super(token: 'dummy-token', userId: userId, name: name, role: role);
}

void main() {
  setUpAll(() {
    // Register a fallback BuildContext for mocktail without generic type
    registerFallbackValue(FakeBuildContext());
  });

  group('WorkerHomeScreen', () {
    late MockJobProvider mockJobProvider;
    late MockAuthProvider mockAuthProvider;

    setUp(() {
      mockJobProvider = MockJobProvider();
      mockAuthProvider = MockAuthProvider();

      // AuthProvider defaults
      when(() => mockAuthProvider.isInitialized).thenReturn(true);
      when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
      when(() => mockAuthProvider.session).thenReturn(
        FakeUserSession(
          userId: 'u1',
          name: 'Worker One',
          role: UserRole.worker,
        ),
      );

      when(() => mockJobProvider.fetchActiveJobs()).thenAnswer((_) async {});
    });

    Widget buildTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<JobProvider>.value(value: mockJobProvider),
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ],
        child: const MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: WorkerHomeScreen(),
        ),
      );
    }

    testWidgets('renders loading state', (WidgetTester tester) async {
      when(() => mockJobProvider.isLoading).thenReturn(true);
      when(() => mockJobProvider.jobs).thenReturn([]);
      when(() => mockJobProvider.errorMessage).thenReturn(null);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(); // allow any async rebuilds

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders empty state when no jobs', (
      WidgetTester tester,
    ) async {
      when(() => mockJobProvider.isLoading).thenReturn(false);
      when(() => mockJobProvider.jobs).thenReturn([]);
      when(() => mockJobProvider.errorMessage).thenReturn(null);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('No active jobs'), findsOneWidget);
    });

    testWidgets('renders error state with retry button', (
      WidgetTester tester,
    ) async {
      when(() => mockJobProvider.isLoading).thenReturn(false);
      when(() => mockJobProvider.jobs).thenReturn([]);
      when(() => mockJobProvider.errorMessage).thenReturn('Network error');
      when(() => mockJobProvider.fetchActiveJobs()).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Network error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      verify(() => mockJobProvider.fetchActiveJobs()).called(1);
    });

    testWidgets('renders multiple active jobs correctly', (
      WidgetTester tester,
    ) async {
      final job1 = Job(
        id: 'j1',
        jobNumber: 'JOB-001',
        companyName: 'Acme Corp',
        status: 'IN_PROGRESS',
        chalanNumber: null,
        createdBy: 'worker',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        completedAt: null,
        steps: [
          JobStep(
            id: 's1',
            stepName: 'Cutting',
            stepOrder: 1,
            status: JobStepStatus.completed,
          ),
          JobStep(
            id: 's2',
            stepName: 'Drilling',
            stepOrder: 2,
            status: JobStepStatus.pending,
          ),
        ],
      );
      final job2 = Job(
        id: 'j2',
        jobNumber: 'JOB-002',
        companyName: 'Beta Ltd',
        status: 'IN_PROGRESS',
        chalanNumber: null,
        createdBy: 'worker',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        completedAt: null,
        steps: [
          JobStep(
            id: 's1',
            stepName: 'Assembly',
            stepOrder: 1,
            status: JobStepStatus.inProgress,
          ),
        ],
      );

      when(() => mockJobProvider.isLoading).thenReturn(false);
      when(() => mockJobProvider.jobs).thenReturn([job1, job2]);
      when(() => mockJobProvider.errorMessage).thenReturn(null);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Verify both job numbers appear
      expect(find.text('JOB-001'), findsOneWidget);
      expect(find.text('JOB-002'), findsOneWidget);

      // Verify company names
      expect(find.text('Acme Corp'), findsOneWidget);
      expect(find.text('Beta Ltd'), findsOneWidget);

      // Verify progress text
      expect(find.text('1 / 2 steps'), findsOneWidget);
      expect(find.text('0 / 1 steps'), findsOneWidget);

      // Verify next step names
      expect(find.text('Next: Drilling'), findsOneWidget);
      expect(find.text('Next: Assembly'), findsOneWidget);
    });

    testWidgets('tapping a job navigates to detail route', (
      WidgetTester tester,
    ) async {
      final job = Job(
        id: 'j1',
        jobNumber: 'JOB-001',
        companyName: 'Acme Corp',
        status: 'IN_PROGRESS',
        chalanNumber: null,
        createdBy: 'worker',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        completedAt: null,
        steps: [],
      );

      // Stub provider behavior for the detail screen
      when(() => mockJobProvider.isLoading).thenReturn(false);
      when(() => mockJobProvider.jobs).thenReturn([job]);
      when(() => mockJobProvider.errorMessage).thenReturn(null);
      when(() => mockJobProvider.isDetailLoading).thenReturn(false);
      when(() => mockJobProvider.selectedJob).thenReturn(job);
      when(() => mockJobProvider.detailErrorMessage).thenReturn(null);
      when(
        () => mockJobProvider.fetchJobDetail(any()),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.text('JOB-001'));
      await tester.pumpAndSettle();

      // Verify that the detail screen shows the job number
      expect(find.text('JOB #${job.jobNumber}'), findsOneWidget);
    });

    testWidgets('pull-to-refresh triggers refreshJobs', (
      WidgetTester tester,
    ) async {
      final dummyJob = Job(
        id: 'j2',
        jobNumber: 'JOB-002',
        companyName: 'Dummy Corp',
        status: 'IN_PROGRESS',
        chalanNumber: null,
        createdBy: 'worker',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        completedAt: null,
        steps: [],
      );

      when(() => mockJobProvider.isLoading).thenReturn(false);
      when(() => mockJobProvider.jobs).thenReturn([dummyJob]);
      when(() => mockJobProvider.errorMessage).thenReturn(null);
      when(() => mockJobProvider.refreshJobs()).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      final listFinder = find.byType(ListView);
      expect(listFinder, findsOneWidget);

      await tester.drag(listFinder, const Offset(0.0, 300.0));
      await tester.pumpAndSettle();

      verify(() => mockJobProvider.refreshJobs()).called(1);
    });

    testWidgets('logout button invokes AuthProvider.logout', (
      WidgetTester tester,
    ) async {
      when(() => mockJobProvider.isLoading).thenReturn(false);
      when(() => mockJobProvider.jobs).thenReturn([]);
      when(() => mockJobProvider.errorMessage).thenReturn(null);
      when(() => mockAuthProvider.logout()).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      verify(() => mockAuthProvider.logout()).called(1);
    });
  });
}

// Helper class to satisfy mocktail's BuildContext requirement
class FakeBuildContext extends Fake implements BuildContext {}
