import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:frontend/core/errors/api_exception.dart';
import 'package:frontend/models/notification_item.dart';
import 'package:frontend/providers/notification_provider.dart';
import 'package:frontend/services/notification_service.dart';

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  late MockNotificationService mockService;
  late NotificationProvider provider;

  setUp(() {
    mockService = MockNotificationService();
    provider = NotificationProvider(notificationService: mockService);
  });

  group('NotificationProvider.fetchNotifications', () {
    test('1. successful notification fetch sets notifications and clears loading', () async {
      final mockList = [
        NotificationItem(
          id: 'notif-1',
          jobId: 'job-1',
          message: 'Job #1704: Cutting completed by Bob.',
          isRead: false,
          createdAt: DateTime.parse('2026-09-12T10:00:00Z'),
        ),
        NotificationItem(
          id: 'notif-2',
          jobId: 'job-1',
          message: 'Job #1704: Welding completed by Alice.',
          isRead: true,
          createdAt: DateTime.parse('2026-09-12T09:00:00Z'),
        ),
      ];

      when(() => mockService.getNotifications()).thenAnswer((_) async => mockList);

      final future = provider.fetchNotifications();
      expect(provider.isLoading, isTrue);
      expect(provider.errorMessage, isNull);

      await future;

      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.notifications.length, 2);
      expect(provider.unreadCount, 1);
      verify(() => mockService.getNotifications()).called(1);
    });

    test('2. empty notification list results in unreadCount = 0', () async {
      when(() => mockService.getNotifications()).thenAnswer((_) async => []);

      await provider.fetchNotifications();

      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.notifications, isEmpty);
      expect(provider.unreadCount, 0);
    });

    test('3. API error during fetch sets errorMessage', () async {
      when(() => mockService.getNotifications())
          .thenThrow(const ApiException(message: 'Failed to load notifications'));

      await provider.fetchNotifications();

      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, 'Failed to load notifications');
      expect(provider.notifications, isEmpty);
    });

    test('4. unexpected error during fetch sets fallback message', () async {
      when(() => mockService.getNotifications())
          .thenThrow(Exception('Socket broken'));

      await provider.fetchNotifications();

      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, 'An unexpected error occurred.');
    });
  });

  group('NotificationProvider.markAsRead', () {
    test('6, 7. successful mark as read updates item and decrements unreadCount', () async {
      final initialList = [
        NotificationItem(
          id: 'notif-1',
          jobId: 'job-1',
          message: 'Step completed',
          isRead: false,
          createdAt: DateTime.parse('2026-09-12T10:00:00Z'),
        ),
        NotificationItem(
          id: 'notif-2',
          jobId: 'job-2',
          message: 'Step 2 completed',
          isRead: false,
          createdAt: DateTime.parse('2026-09-12T10:05:00Z'),
        ),
      ];

      when(() => mockService.getNotifications()).thenAnswer((_) async => initialList);
      await provider.fetchNotifications();
      expect(provider.unreadCount, 2);

      final updatedNotif = initialList[0].copyWith(isRead: true);
      when(() => mockService.markAsRead('notif-1')).thenAnswer((_) async => updatedNotif);

      final markFuture = provider.markAsRead('notif-1');
      expect(provider.markingReadId, 'notif-1');

      await markFuture;

      expect(provider.markingReadId, isNull);
      expect(provider.notifications[0].isRead, isTrue);
      expect(provider.notifications[1].isRead, isFalse);
      expect(provider.unreadCount, 1);
      verify(() => mockService.markAsRead('notif-1')).called(1);
    });

    test('8. API error while marking as read sets actionError without breaking state', () async {
      final initialList = [
        NotificationItem(
          id: 'notif-1',
          jobId: 'job-1',
          message: 'Step completed',
          isRead: false,
          createdAt: DateTime.parse('2026-09-12T10:00:00Z'),
        ),
      ];
      when(() => mockService.getNotifications()).thenAnswer((_) async => initialList);
      await provider.fetchNotifications();

      when(() => mockService.markAsRead('notif-1'))
          .thenThrow(const ApiException(message: 'Notification not found'));

      await provider.markAsRead('notif-1');

      expect(provider.actionError, 'Notification not found');
      expect(provider.notifications[0].isRead, isFalse);
      expect(provider.unreadCount, 1);
    });
  });

  group('NotificationProvider.fetchUnreadNotifications', () {
    test('5. updates unread count based on unread endpoint response', () async {
      final unreadList = [
        NotificationItem(
          id: 'notif-1',
          jobId: 'job-1',
          message: 'New step completed',
          isRead: false,
          createdAt: DateTime.parse('2026-09-12T10:00:00Z'),
        ),
      ];
      when(() => mockService.getUnreadNotifications()).thenAnswer((_) async => unreadList);

      await provider.fetchUnreadNotifications();

      expect(provider.unreadCount, 1);
      expect(provider.notifications.length, 1);
    });
  });
}
