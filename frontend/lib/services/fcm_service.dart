import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';


class FcmService {
  static bool _initialized = false;

  /// Initialize Firebase (if not already) and register the device FCM token
  /// with the backend. This should be called after a valid authenticated
  /// session exists. Errors are caught and logged; they do not propagate
  /// to break the UI.
  static Future<void> initialize(ApiClient apiClient) async {
    if (_initialized) return;
    _initialized = true;
    try {
      // Initialize Firebase. If google-services.json is missing, this may
      // still succeed on Android but push notifications will not work.
      await Firebase.initializeApp();
    } catch (e) {
      // Log but continue – Firebase is not critical for the app.
      if (kDebugMode) {
        print('Firebase initialization failed: $e');
      }
      return;
    }

    // Request permission on Android (iOS also handled by the plugin).
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (e) {
      if (kDebugMode) {
        print('FCM permission request failed: $e');
      }
    }

    // Register current token.
    _registerToken(apiClient);

    // Listen for token refreshes.
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await _sendTokenToBackend(newToken, apiClient);
    });

    // Optional: handle foreground messages (simple SnackBar example).
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('FCM foreground message: ${message.notification?.title ?? ''} - ${message.notification?.body ?? ''}');
      }
      // No UI handling here to keep it non‑intrusive.
    });
  }

  static Future<void> _registerToken(ApiClient apiClient) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _sendTokenToBackend(token, apiClient);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get FCM token: $e');
      }
    }
  }

  static Future<void> _sendTokenToBackend(String token, ApiClient apiClient) async {
    try {
      try {
        await apiClient.post(
          ApiConfig.fcmTokenEndpoint,
          body: {'token': token},
          authenticated: true,
        ).timeout(const Duration(seconds: 2));
      } catch (e) {
        if (kDebugMode) {
          print('Failed to register FCM token with backend (timeout): $e');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to register FCM token with backend: $e');
      }
    }
  }
}
