import 'package:flutter/foundation.dart';

import '../core/errors/api_exception.dart';
import '../models/notification_item.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService;

  NotificationProvider({NotificationService? notificationService})
      : _notificationService = notificationService ?? NotificationService();

  List<NotificationItem> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

  String? _markingReadId;
  String? _actionError;

  List<NotificationItem> get notifications => List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String? get markingReadId => _markingReadId;
  String? get actionError => _actionError;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Fetches all notifications for the authenticated user.
  Future<void> fetchNotifications() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _notifications = await _notificationService.getNotifications();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'An unexpected error occurred.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches only unread notifications to refresh unread count.
  Future<void> fetchUnreadNotifications() async {
    try {
      final unreadList = await _notificationService.getUnreadNotifications();
      // Update unread status in the existing list if present, or replace
      final unreadMap = {for (var item in unreadList) item.id: item};
      if (_notifications.isNotEmpty) {
        _notifications = _notifications.map((item) {
          if (unreadMap.containsKey(item.id)) {
            return unreadMap[item.id]!;
          } else {
            return item.copyWith(isRead: true);
          }
        }).toList();
      } else {
        _notifications = unreadList;
      }
      notifyListeners();
    } catch (_) {
      // Background unread poll fails silently
    }
  }

  /// Marks a notification as read and updates state.
  Future<void> markAsRead(String notificationId) async {
    if (_markingReadId == notificationId) return;

    _markingReadId = notificationId;
    _actionError = null;
    notifyListeners();

    try {
      final updated = await _notificationService.markAsRead(notificationId);
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = updated;
      }
    } on ApiException catch (e) {
      _actionError = e.message;
    } catch (_) {
      _actionError = 'Failed to mark notification as read.';
    } finally {
      _markingReadId = null;
      notifyListeners();
    }
  }

  /// Clears any transient action error.
  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }
}
