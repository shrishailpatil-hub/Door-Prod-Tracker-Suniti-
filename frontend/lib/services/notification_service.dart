import '../core/config/api_config.dart';
import '../core/errors/api_exception.dart';
import '../core/network/api_client.dart';
import '../models/notification_item.dart';

class NotificationService {
  final ApiClient _apiClient;

  NotificationService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Fetches all notifications for the authenticated user, newest first.
  Future<List<NotificationItem>> getNotifications() async {
    final response = await _apiClient.get(ApiConfig.notificationsEndpoint);
    if (response is! List) {
      throw const ApiException(
        message: 'Unexpected response format for notifications',
      );
    }
    return response
        .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches only unread notifications for the authenticated user.
  Future<List<NotificationItem>> getUnreadNotifications() async {
    final response = await _apiClient.get('${ApiConfig.notificationsEndpoint}/unread');
    if (response is! List) {
      throw const ApiException(
        message: 'Unexpected response format for unread notifications',
      );
    }
    return response
        .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Marks a specific notification as read.
  Future<NotificationItem> markAsRead(String notificationId) async {
    final response = await _apiClient.put(
      '${ApiConfig.notificationsEndpoint}/$notificationId/read',
    );
    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'Unexpected response format for updated notification',
      );
    }
    return NotificationItem.fromJson(response);
  }
}
