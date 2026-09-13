import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/config/app_router.dart';
import 'package:frontend/models/auth/user_role.dart';
import 'package:frontend/models/auth/user_session.dart';
import 'package:frontend/providers/admin_process_step_provider.dart';
import 'package:frontend/providers/admin_user_provider.dart';
import 'package:frontend/providers/admin_log_provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/admin/admin_dashboard_screen.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockAdminUserProvider extends Mock implements AdminUserProvider {}

class MockAdminProcessStepProvider extends Mock
    implements AdminProcessStepProvider {}

class MockAdminLogProvider extends Mock implements AdminLogProvider {}

void main() {
  late MockAuthProvider authProvider;
  late MockAdminUserProvider adminUserProvider;
  late MockAdminProcessStepProvider adminProcessStepProvider;
  late MockAdminLogProvider adminLogProvider;

  setUp(() {
    authProvider = MockAuthProvider();
    adminUserProvider = MockAdminUserProvider();
    adminProcessStepProvider = MockAdminProcessStepProvider();
    adminLogProvider = MockAdminLogProvider();

    when(() => adminUserProvider.isLoading).thenReturn(false);
    when(() => adminUserProvider.users).thenReturn([]);
    when(() => adminUserProvider.errorMessage).thenReturn(null);
    when(() => adminUserProvider.fetchUsers()).thenAnswer((_) async {});

    when(() => adminProcessStepProvider.isLoading).thenReturn(false);
    when(() => adminProcessStepProvider.steps).thenReturn([]);
    when(() => adminProcessStepProvider.activeSteps).thenReturn([]);
    when(() => adminProcessStepProvider.inactiveSteps).thenReturn([]);
    when(() => adminProcessStepProvider.errorMessage).thenReturn(null);
    when(() => adminProcessStepProvider.fetchProcessSteps()).thenAnswer((_) async {});

    when(() => adminLogProvider.isLoading).thenReturn(false);
    when(() => adminLogProvider.logs).thenReturn([]);
    when(() => adminLogProvider.errorMessage).thenReturn(null);
    when(() => adminLogProvider.isExporting).thenReturn(false);
    when(() => adminLogProvider.exportErrorMessage).thenReturn(null);
    when(() => adminLogProvider.fetchLogs()).thenAnswer((_) async {});

    when(() => authProvider.session).thenReturn(
      const UserSession(
        token: 'token',
        userId: 'admin-1',
        name: 'Admin Priya',
        role: UserRole.admin,
      ),
    );
    when(() => authProvider.isInitialized).thenReturn(true);
    when(() => authProvider.isAuthenticated).thenReturn(true);
    when(() => authProvider.isLoading).thenReturn(false);
    when(() => authProvider.logout()).thenAnswer((_) async {
      when(() => authProvider.isAuthenticated).thenReturn(false);
    });
  });

  Widget buildDashboard() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<AdminUserProvider>.value(
          value: adminUserProvider,
        ),
        ChangeNotifierProvider<AdminProcessStepProvider>.value(
          value: adminProcessStepProvider,
        ),
        ChangeNotifierProvider<AdminLogProvider>.value(
          value: adminLogProvider,
        ),
      ],
      child: const MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: AdminDashboardScreen(),
      ),
    );
  }

  test('role home routes resolve to the expected screens', () {
    expect(AppRouter.getHomeRouteForRole(UserRole.admin), AppRouter.adminHome);
    expect(
      AppRouter.getHomeRouteForRole(UserRole.manager),
      AppRouter.managerHome,
    );
    expect(
      AppRouter.getHomeRouteForRole(UserRole.worker),
      AppRouter.workerHome,
    );
  });

  testWidgets('renders administrator details and all navigation entries', (
    tester,
  ) async {
    await tester.pumpWidget(buildDashboard());

    expect(find.text('Admin Priya'), findsOneWidget);
    expect(find.text('ADMIN'), findsOneWidget);
    expect(find.text('User Management'), findsOneWidget);
    expect(find.text('Process Steps'), findsOneWidget);
    expect(find.text('Logs / Export'), findsOneWidget);
    expect(find.byTooltip('Logout'), findsOneWidget);
  });

  testWidgets('navigation entries open their route foundations', (
    tester,
  ) async {
    await tester.pumpWidget(buildDashboard());

    await tester.tap(find.text('User Management'));
    await tester.pumpAndSettle();
    expect(find.text('Users'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Process Steps'));
    await tester.pumpAndSettle();
    expect(find.text('Process Steps'), findsWidgets);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Logs / Export'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Logs / Export'));
    await tester.pumpAndSettle();
    expect(find.text('Audit Logs'), findsOneWidget);
  });

  testWidgets('logout delegates to the authentication provider', (
    tester,
  ) async {
    await tester.pumpWidget(buildDashboard());

    await tester.tap(find.byTooltip('Logout'));
    await tester.pumpAndSettle();

    verify(() => authProvider.logout()).called(1);
    expect(find.text('Door Process Workflow'), findsOneWidget);
  });

  testWidgets('uses one column on a phone-sized display without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildDashboard());

    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses two columns on a tablet-sized display without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildDashboard());

    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      2,
    );
    expect(tester.takeException(), isNull);
  });
}
