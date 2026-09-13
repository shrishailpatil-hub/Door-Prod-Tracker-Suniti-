import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/config/app_router.dart';
import 'package:frontend/models/notification_item.dart';
import 'package:frontend/providers/notification_provider.dart';
import 'package:frontend/screens/manager/manager_notifications_screen.dart';

import 'package:frontend/providers/job_provider.dart';

class MockNotificationProvider extends Mock implements NotificationProvider {}
class MockJobProvider extends Mock implements JobProvider {}

void main() {
  late MockNotificationProvider mockProvider;
  late MockJobProvider mockJobProvider;

  setUp(() {
    mockProvider = MockNotificationProvider();
    mockJobProvider = MockJobProvider();

    when(() => mockProvider.isLoading).thenReturn(false);
    when(() => mockProvider.notifications).thenReturn([]);
    when(() => mockProvider.errorMessage).thenReturn(null);
    when(() => mockProvider.unreadCount).thenReturn(0);
    when(() => mockProvider.fetchNotifications()).thenAnswer((_) async {});
    when(() => mockProvider.markAsRead(any())).thenAnswer((_) async {});

    when(() => mockJobProvider.isManagerDetailLoading).thenReturn(false);
    when(() => mockJobProvider.managerSelectedJob).thenReturn(null);
    when(() => mockJobProvider.managerDetailErrorMessage).thenReturn(null);
    when(() => mockJobProvider.fetchManagerJob(any())).thenAnswer((_) async {});
  });

  Widget buildTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<NotificationProvider>.value(value: mockProvider),
        ChangeNotifierProvider<JobProvider>.value(value: mockJobProvider),
      ],
      child: const MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: ManagerNotificationsScreen(),
      ),
    );
  }

  group('ManagerNotificationsScreen Widget Tests', () {
    testWidgets('1. Shows loading indicator when loading and list is empty', (tester) async {
      when(() => mockProvider.isLoading).thenReturn(true);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('2. Shows empty state message when notifications list is empty', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('No notifications available'), findsOneWidget);
    });

    testWidgets('3, 4. Shows error message and retry button triggers fetchNotifications', (tester) async {
      when(() => mockProvider.errorMessage).thenReturn('Failed to load notifications');

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Failed to load notifications'), findsOneWidget);
      final retryButton = find.widgetWithText(ElevatedButton, 'Retry');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      verify(() => mockProvider.fetchNotifications()).called(greaterThanOrEqualTo(1));
    });

    testWidgets('5, 6, 7. Displays notifications with correct unread badge and read styling', (tester) async {
      final items = [
        NotificationItem(
          id: 'notif-1',
          jobId: 'job-101',
          message: 'Job #101: Cutting completed by Bob.',
          isRead: false,
          createdAt: DateTime.parse('2026-09-12T10:00:00.000Z'),
        ),
        NotificationItem(
          id: 'notif-2',
          jobId: 'job-102',
          message: 'Job #102: Welding completed by Alice.',
          isRead: true,
          createdAt: DateTime.parse('2026-09-12T09:00:00.000Z'),
        ),
      ];
      when(() => mockProvider.notifications).thenReturn(items);
      when(() => mockProvider.unreadCount).thenReturn(1);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Job #101: Cutting completed by Bob.'), findsOneWidget);
      expect(find.text('Job #102: Welding completed by Alice.'), findsOneWidget);
      // Unread notification displays the NEW badge
      expect(find.text('NEW'), findsOneWidget);
    });

    testWidgets('8. Tapping an unread notification triggers markAsRead', (tester) async {
      final items = [
        NotificationItem(
          id: 'notif-1',
          jobId: 'job-101',
          message: 'Job #101: Cutting completed by Bob.',
          isRead: false,
          createdAt: DateTime.parse('2026-09-12T10:00:00.000Z'),
        ),
      ];
      when(() => mockProvider.notifications).thenReturn(items);
      when(() => mockProvider.unreadCount).thenReturn(1);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Job #101: Cutting completed by Bob.'));
      await tester.pumpAndSettle();

      verify(() => mockProvider.markAsRead('notif-1')).called(1);
    });

    testWidgets('9. Pull-to-refresh triggers fetchNotifications', (tester) async {
      final items = [
        NotificationItem(
          id: 'notif-1',
          jobId: 'job-101',
          message: 'Job #101: Cutting completed by Bob.',
          isRead: true,
          createdAt: DateTime.parse('2026-09-12T10:00:00.000Z'),
        ),
      ];
      when(() => mockProvider.notifications).thenReturn(items);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(ListView),
        const Offset(0.0, 300.0),
        1000.0,
      );
      await tester.pumpAndSettle();

      verify(() => mockProvider.fetchNotifications()).called(greaterThanOrEqualTo(1));
    });
  });
}
