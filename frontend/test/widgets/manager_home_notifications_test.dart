import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/config/app_router.dart';
import 'package:frontend/models/auth/user_role.dart';
import 'package:frontend/models/auth/user_session.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/job_provider.dart';
import 'package:frontend/providers/notification_provider.dart';
import 'package:frontend/screens/manager/manager_home_screen.dart';
import 'package:frontend/screens/manager/manager_notifications_screen.dart';

class MockJobProvider extends Mock implements JobProvider {}
class MockAuthProvider extends Mock implements AuthProvider {}
class MockNotificationProvider extends Mock implements NotificationProvider {}

void main() {
  late MockJobProvider mockJobProvider;
  late MockAuthProvider mockAuthProvider;
  late MockNotificationProvider mockNotificationProvider;

  setUp(() {
    mockJobProvider = MockJobProvider();
    mockAuthProvider = MockAuthProvider();
    mockNotificationProvider = MockNotificationProvider();

    when(() => mockAuthProvider.isInitialized).thenReturn(true);
    when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
    when(() => mockAuthProvider.session).thenReturn(
      const UserSession(
        token: 'token',
        userId: 'm-1',
        name: 'Manager Alice',
        role: UserRole.manager,
      ),
    );

    when(() => mockJobProvider.isManagerLoading).thenReturn(false);
    when(() => mockJobProvider.managerJobs).thenReturn([]);
    when(() => mockJobProvider.managerErrorMessage).thenReturn(null);
    when(() => mockJobProvider.fetchManagerJobs()).thenAnswer((_) async {});

    when(() => mockNotificationProvider.isLoading).thenReturn(false);
    when(() => mockNotificationProvider.notifications).thenReturn([]);
    when(() => mockNotificationProvider.errorMessage).thenReturn(null);
    when(() => mockNotificationProvider.unreadCount).thenReturn(0);
    when(() => mockNotificationProvider.fetchNotifications()).thenAnswer((_) async {});
  });

  Widget buildManagerHome() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<JobProvider>.value(value: mockJobProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ChangeNotifierProvider<NotificationProvider>.value(value: mockNotificationProvider),
      ],
      child: const MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: ManagerHomeScreen(),
      ),
    );
  }

  group('ManagerHomeScreen Notifications Integration', () {
    testWidgets('1. Notification icon exists in AppBar', (tester) async {
      await tester.pumpWidget(buildManagerHome());
      await tester.pumpAndSettle();

      expect(find.byTooltip('Notifications'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('2. Badge does not appear when unread count = 0', (tester) async {
      when(() => mockNotificationProvider.unreadCount).thenReturn(0);

      await tester.pumpWidget(buildManagerHome());
      await tester.pumpAndSettle();

      final badgeFinder = find.byType(Badge);
      expect(badgeFinder, findsOneWidget);
      final badgeWidget = tester.widget<Badge>(badgeFinder);
      expect(badgeWidget.isLabelVisible, isFalse);
    });

    testWidgets('3. Unread badge appears with count when unread count > 0', (tester) async {
      when(() => mockNotificationProvider.unreadCount).thenReturn(3);

      await tester.pumpWidget(buildManagerHome());
      await tester.pumpAndSettle();

      final badgeFinder = find.byType(Badge);
      expect(badgeFinder, findsOneWidget);
      final badgeWidget = tester.widget<Badge>(badgeFinder);
      expect(badgeWidget.isLabelVisible, isTrue);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('4. Tapping notification icon navigates to ManagerNotificationsScreen', (tester) async {
      await tester.pumpWidget(buildManagerHome());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      expect(find.byType(ManagerNotificationsScreen), findsOneWidget);
    });
  });
}
