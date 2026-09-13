import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_router.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/models/auth/app_user.dart';
import 'package:frontend/models/auth/user_role.dart';
import 'package:frontend/providers/admin_user_provider.dart';
import 'package:frontend/screens/admin/admin_user_list_screen.dart';
import 'package:frontend/services/admin_user_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockAdminUserProvider extends Mock implements AdminUserProvider {}

class MockAdminUserService extends Mock implements AdminUserService {}

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockAdminUserProvider mockUserProvider;

  final adminUser = AppUser(
    id: 'u-admin-1',
    name: 'Alice Admin',
    email: 'alice@doorcorp.com',
    role: UserRole.admin,
    isActive: true,
    createdAt: DateTime.parse('2026-09-01T10:00:00Z'),
  );

  final managerUser = AppUser(
    id: 'u-manager-1',
    name: 'Bob Manager',
    email: 'bob@doorcorp.com',
    role: UserRole.manager,
    isActive: true,
    createdAt: DateTime.parse('2026-09-02T10:00:00Z'),
  );

  final workerUser = AppUser(
    id: 'u-worker-1',
    name: 'Charlie Worker',
    email: 'charlie@doorcorp.com',
    role: UserRole.worker,
    isActive: false,
    createdAt: DateTime.parse('2026-09-03T10:00:00Z'),
  );

  setUp(() {
    mockUserProvider = MockAdminUserProvider();
    when(() => mockUserProvider.isLoading).thenReturn(false);
    when(() => mockUserProvider.users).thenReturn([]);
    when(() => mockUserProvider.errorMessage).thenReturn(null);
    when(() => mockUserProvider.fetchUsers()).thenAnswer((_) async {});
    when(() => mockUserProvider.refreshUsers()).thenAnswer((_) async {});
     when(() => mockUserProvider.isUpdating).thenReturn(false);

     when(() => mockUserProvider.addListener(any())).thenReturn(null);
     when(() => mockUserProvider.removeListener(any())).thenReturn(null);
     when(() => mockUserProvider.updateUserStatus(id: any(named: 'id'), isActive: any(named: 'isActive'))).thenAnswer((_) async {});
  });

    Widget buildTestWidget() {
      return MediaQuery(
        data: const MediaQueryData(size: Size(1200, 800)),
        child: ChangeNotifierProvider<AdminUserProvider>.value(
          value: mockUserProvider,
          child: MaterialApp(
            onGenerateRoute: (settings) {
              if (settings.name == AppRouter.adminEditUser) {
                return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('Edit Screen'))));
              }
              if (settings.name == AppRouter.adminCreateUser) {
                return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('Create User Screen'))));
              }
              return AppRouter.onGenerateRoute(settings);
            },
            home: const AdminUserListScreen(),
          ),
        ),
      );
    }

  group('AdminUserListScreen Tests', () {
    testWidgets('1. Admin User List screen renders title and back button', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Users'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('2. Displays loading indicator when users are loading', (
      tester,
    ) async {
      when(() => mockUserProvider.isLoading).thenReturn(true);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('3. Users are displayed correctly with name and email', (
      tester,
    ) async {
      when(
        () => mockUserProvider.users,
      ).thenReturn([adminUser, managerUser, workerUser]);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Alice Admin'), findsOneWidget);
      expect(find.text('alice@doorcorp.com'), findsOneWidget);
      expect(find.text('Bob Manager'), findsOneWidget);
      expect(find.text('bob@doorcorp.com'), findsOneWidget);
      expect(find.text('Charlie Worker'), findsOneWidget);
      expect(find.text('charlie@doorcorp.com'), findsOneWidget);
    });

    testWidgets('4. ADMIN user is displayed with role badge', (tester) async {
      when(() => mockUserProvider.users).thenReturn([adminUser]);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Alice Admin'), findsOneWidget);
      expect(find.text('ADMIN'), findsOneWidget);
      expect(find.text('(Administrator)'), findsOneWidget);
    });

    testWidgets('5. MANAGER user is displayed with role badge', (tester) async {
      when(() => mockUserProvider.users).thenReturn([managerUser]);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Bob Manager'), findsOneWidget);
      expect(find.text('MANAGER'), findsOneWidget);
      expect(find.text('(Floor Manager)'), findsOneWidget);
    });

    testWidgets('6. WORKER user is displayed with role badge', (tester) async {
      when(() => mockUserProvider.users).thenReturn([workerUser]);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Charlie Worker'), findsOneWidget);
      expect(find.text('WORKER'), findsOneWidget);
      expect(find.text('(Assembly Worker)'), findsOneWidget);
    });

    testWidgets('7. Active status is displayed', (tester) async {
      when(() => mockUserProvider.users).thenReturn([adminUser]); // isActive: true

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('8. Inactive status is displayed', (tester) async {
      when(() => mockUserProvider.users).thenReturn([workerUser]); // isActive: false

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Inactive'), findsOneWidget);
    });

    testWidgets('9. Empty state displays "No users found"', (tester) async {
      when(() => mockUserProvider.users).thenReturn([]);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('No users found'), findsOneWidget);
    });

    testWidgets('10. Displays backend error message when fetch fails', (
      tester,
    ) async {
      when(() => mockUserProvider.errorMessage).thenReturn('Network failure');

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Network failure'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('11. Retry button triggers fetchUsers', (tester) async {
      when(() => mockUserProvider.errorMessage).thenReturn('Failed to load');

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.text('Retry'));
      await tester.pump();

      verify(() => mockUserProvider.fetchUsers()).called(1);
    });

    testWidgets('12. Pull to refresh triggers refreshUsers', (tester) async {
      when(() => mockUserProvider.users).thenReturn([adminUser]);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      final listFinder = find.byType(ListView);
      expect(listFinder, findsOneWidget);

      await tester.drag(listFinder, const Offset(0.0, 300.0));
      await tester.pumpAndSettle();

      verify(() => mockUserProvider.refreshUsers()).called(1);
    });

    testWidgets('13. Service and Provider architecture integration', (
      tester,
    ) async {
      final mockService = MockAdminUserService();
      when(() => mockService.getUsers()).thenAnswer(
        (_) async => [adminUser, managerUser],
      );

      final realProvider = AdminUserProvider(userService: mockService);
      expect(realProvider.isLoading, isFalse);
      expect(realProvider.users, isEmpty);

      await realProvider.fetchUsers();

      expect(realProvider.isLoading, isFalse);
      expect(realProvider.users, hasLength(2));
      expect(realProvider.users[0].name, 'Alice Admin');
      expect(realProvider.users[1].name, 'Bob Manager');
      verify(() => mockService.getUsers()).called(1);
    });

    testWidgets('14. AdminUserService invokes ApiClient /admin/users', (
      tester,
    ) async {
      final mockApiClient = MockApiClient();
      when(() => mockApiClient.get('/admin/users')).thenAnswer(
        (_) async => [
          {
            'id': 'u-test-1',
            'name': 'Dave Worker',
            'email': 'dave@doorcorp.com',
            'role': 'WORKER',
            'isActive': true,
          },
        ],
      );

      final service = AdminUserService(apiClient: mockApiClient);
      final users = await service.getUsers();

      expect(users, hasLength(1));
      expect(users[0].name, 'Dave Worker');
      expect(users[0].role, UserRole.worker);
      expect(users[0].isActive, isTrue);
      verify(() => mockApiClient.get('/admin/users')).called(1);
    });

    testWidgets('15. Active user shows Deactivate button and calls provider.updateUserStatus', (tester) async {
      when(() => mockUserProvider.users).thenReturn([adminUser]);
      when(() => mockUserProvider.isUpdating).thenReturn(false);
      when(() => mockUserProvider.updateUserStatus(id: any(named: 'id'), isActive: any(named: 'isActive'))).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Deactivate icon (toggle_off) should be present
      expect(find.byIcon(Icons.toggle_off), findsOneWidget);

      await tester.tap(find.byIcon(Icons.toggle_off));
      await tester.pump();

      verify(() => mockUserProvider.updateUserStatus(id: adminUser.id, isActive: false)).called(1);
    });

    testWidgets('16. Inactive user shows Activate button and calls provider.updateUserStatus', (tester) async {
      when(() => mockUserProvider.users).thenReturn([workerUser]);
      when(() => mockUserProvider.isUpdating).thenReturn(false);
      when(() => mockUserProvider.updateUserStatus(id: any(named: 'id'), isActive: any(named: 'isActive'))).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Activate icon (toggle_on) should be present
      expect(find.byIcon(Icons.toggle_on), findsOneWidget);

      await tester.tap(find.byIcon(Icons.toggle_on));
      await tester.pump();

      verify(() => mockUserProvider.updateUserStatus(id: workerUser.id, isActive: true)).called(1);
    });

    testWidgets('17. When provider.isUpdating true, action button disabled', (tester) async {
      when(() => mockUserProvider.users).thenReturn([adminUser]);
      when(() => mockUserProvider.isUpdating).thenReturn(true);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Button should be present but disabled (onPressed null). We can attempt tap and verify no call.
      await tester.tap(find.byIcon(Icons.toggle_off));
      await tester.pump();

      verifyNever(() => mockUserProvider.updateUserStatus(id: any(named: 'id'), isActive: any(named: 'isActive')));
    });

    testWidgets('18. Update error message is displayed', (tester) async {
      when(() => mockUserProvider.errorMessage).thenReturn(null);
      when(() => mockUserProvider.updateErrorMessage).thenReturn('Failed to update status');
      when(() => mockUserProvider.users).thenReturn([adminUser]);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Failed to update status'), findsOneWidget);
    });

    testWidgets('19. Edit button navigates to edit screen', (tester) async {
      when(() => mockUserProvider.users).thenReturn([adminUser]);
      when(() => mockUserProvider.errorMessage).thenReturn(null);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap the edit button by icon
      await tester.tap(find.widgetWithIcon(IconButton, Icons.edit));
      await tester.pumpAndSettle();

      expect(find.text('Edit Screen'), findsOneWidget);
    });

    testWidgets('20. Add User action exists and navigates to adminCreateUser', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final addBtn = find.byTooltip('Add User');
      expect(addBtn, findsOneWidget);

      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.text('Create User Screen'), findsOneWidget);
    });
  });
}
