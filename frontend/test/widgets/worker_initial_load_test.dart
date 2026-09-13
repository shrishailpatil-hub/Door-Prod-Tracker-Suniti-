import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_router.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/job_provider.dart';
import 'package:frontend/screens/auth/auth_gate.dart';
import 'package:frontend/screens/worker/worker_home_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../helpers/fake_secure_storage.dart';

class MockJobProvider extends Mock implements JobProvider {}

void main() {
  late FakeFlutterSecureStorage fakeStorage;
  late SecureStorageService storageService;
  late MockJobProvider mockJobProvider;

  setUp(() {
    fakeStorage = FakeFlutterSecureStorage();
    storageService = SecureStorageService(storage: fakeStorage);
    mockJobProvider = MockJobProvider();

    // Worker defaults
    when(() => mockJobProvider.isLoading).thenReturn(false);
    when(() => mockJobProvider.jobs).thenReturn([]);
    when(() => mockJobProvider.errorMessage).thenReturn(null);
    when(() => mockJobProvider.fetchActiveJobs()).thenAnswer((_) async {});

    // Manager defaults
    when(() => mockJobProvider.isManagerLoading).thenReturn(false);
    when(() => mockJobProvider.managerJobs).thenReturn([]);
    when(() => mockJobProvider.managerErrorMessage).thenReturn(null);
    when(() => mockJobProvider.fetchManagerJobs()).thenAnswer((_) async {});
  });

  AuthProvider buildAuthProvider({http.Client? httpClient}) {
    final client =
        httpClient ??
        MockClient((_) async {
          throw UnimplementedError();
        });
    return AuthProvider(
      apiClient: ApiClient(
        baseUrl: 'http://example.com/api',
        storageService: storageService,
        httpClient: client,
      ),
      storageService: storageService,
    );
  }

  Widget buildApp(AuthProvider authProvider) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<JobProvider>.value(value: mockJobProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: const AuthGate(),
      ),
    );
  }

  group('Worker Initial-Load / Startup Sequencing Tests', () {
    testWidgets(
      '1. Worker jobs are not fetched before authentication/session restoration finishes',
      (tester) async {
        final authProvider = buildAuthProvider();
        // authProvider.initialize() is NOT awaited yet, so isInitialized is false

        await tester.pumpWidget(buildApp(authProvider));

        expect(find.text('Loading Application...'), findsOneWidget);
        verifyNever(() => mockJobProvider.fetchActiveJobs());
      },
    );

    testWidgets(
      '2. Unauthenticated startup displays Login and does NOT call Worker jobs API',
      (tester) async {
        final authProvider = buildAuthProvider();
        await authProvider.initialize();

        await tester.pumpWidget(buildApp(authProvider));
        await tester.pumpAndSettle();

        expect(find.text('Door Process Workflow'), findsOneWidget);
        expect(find.text('Sign in'), findsOneWidget);
        verifyNever(() => mockJobProvider.fetchActiveJobs());
      },
    );

    testWidgets(
      '3. Manager startup restores session and does NOT call Worker jobs API',
      (tester) async {
        await storageService.saveSession(
          token: 'manager-token',
          userId: 'mgr-1',
          name: 'Manager Ravi',
          role: 'MANAGER',
        );

        final authProvider = buildAuthProvider();
        await authProvider.initialize();

        await tester.pumpWidget(buildApp(authProvider));
        await tester.pumpAndSettle();

        expect(find.text('Manager Dashboard'), findsOneWidget);
        verifyNever(() => mockJobProvider.fetchActiveJobs());
      },
    );

    testWidgets(
      '4. Admin startup restores session and does NOT call Worker jobs API',
      (tester) async {
        await storageService.saveSession(
          token: 'admin-token',
          userId: 'adm-1',
          name: 'Admin Maya',
          role: 'ADMIN',
        );

        final authProvider = buildAuthProvider();
        await authProvider.initialize();

        await tester.pumpWidget(buildApp(authProvider));
        await tester.pumpAndSettle();

        expect(find.text('Admin Dashboard'), findsOneWidget);
        verifyNever(() => mockJobProvider.fetchActiveJobs());
      },
    );

    testWidgets(
      '5. Authenticated Worker entering Worker Home via session restoration performs exactly one initial job fetch',
      (tester) async {
        await storageService.saveSession(
          token: 'worker-token',
          userId: 'wkr-1',
          name: 'Worker Bob',
          role: 'WORKER',
        );

        final authProvider = buildAuthProvider();
        await authProvider.initialize();

        await tester.pumpWidget(buildApp(authProvider));
        await tester.pumpAndSettle();

        expect(find.text('Active Jobs'), findsOneWidget);
        verify(() => mockJobProvider.fetchActiveJobs()).called(1);
      },
    );

    testWidgets(
      '6. Worker login transition to Worker Home triggers initial job fetch',
      (tester) async {
        final authProvider = buildAuthProvider(
          httpClient: MockClient((request) async {
            return http.Response(
              jsonEncode({
                'token': 'worker-login-token',
                'userId': 'wkr-2',
                'name': 'Worker Sunita',
                'role': 'WORKER',
              }),
              200,
            );
          }),
        );
        await authProvider.initialize();

        await tester.pumpWidget(buildApp(authProvider));
        await tester.pumpAndSettle();

        expect(find.text('Sign in'), findsOneWidget);
        verifyNever(() => mockJobProvider.fetchActiveJobs());

        await tester.enterText(
          find.byType(TextFormField).first,
          'worker@example.com',
        );
        await tester.enterText(find.byType(TextFormField).last, 'pass1234');
        await tester.tap(find.text('Sign in'));
        await tester.pumpAndSettle();

        expect(find.text('Active Jobs'), findsOneWidget);
        verify(() => mockJobProvider.fetchActiveJobs()).called(1);
      },
    );

    testWidgets(
      '7. Rebuilding WorkerHomeScreen does not re-trigger initial fetch (duplicate protection)',
      (tester) async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<JobProvider>.value(value: mockJobProvider),
              ChangeNotifierProvider<AuthProvider>.value(
                value: buildAuthProvider(),
              ),
            ],
            child: const MaterialApp(home: WorkerHomeScreen()),
          ),
        );
        await tester.pump();

        // fetchActiveJobs should still only have been called once across rebuilds
        verify(() => mockJobProvider.fetchActiveJobs()).called(1);
      },
    );
  });
}
