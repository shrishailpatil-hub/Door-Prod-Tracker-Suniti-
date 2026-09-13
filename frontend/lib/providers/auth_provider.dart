import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../core/errors/api_exception.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_storage_service.dart';
import '../models/auth/login_response.dart';
import '../models/auth/user_role.dart';
import '../models/auth/user_session.dart';

/// Provider handling authentication state, user session lifecycle, login, and logout.
class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  final SecureStorageService _storageService;

  UserSession? _session;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  AuthProvider({ApiClient? apiClient, SecureStorageService? storageService})
    : _storageService = storageService ?? SecureStorageService(),
      _apiClient =
          apiClient ??
          ApiClient(storageService: storageService ?? SecureStorageService());

  UserSession? get session => _session;
  bool get isAuthenticated => _session != null;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  UserRole? get userRole => _session?.role;

  /// Restores persistent session on application startup.
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _storageService.getToken();
      final userId = await _storageService.getUserId();
      final name = await _storageService.getUserName();
      final roleStr = await _storageService.getUserRole();

      if (token != null &&
          token.isNotEmpty &&
          userId != null &&
          name != null &&
          roleStr != null) {
        final role = UserRole.fromString(roleStr);
        _session = UserSession(
          token: token,
          userId: userId,
          name: name,
          role: role,
        );
      } else {
        _session = null;
      }
    } catch (e) {
      _session = null;
      // Reset invalid stored credentials
      await _storageService.clearSession();
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Authenticates user with email and password.
  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final responseData = await _apiClient.post(
        ApiConfig.loginEndpoint,
        body: {'email': email.trim(), 'password': password},
        authenticated: false,
      );

      if (responseData is! Map<String, dynamic>) {
        throw const ApiException(
          message: 'Invalid server response format during authentication.',
        );
      }

      final loginResponse = LoginResponse.fromJson(responseData);

      await _storageService.saveSession(
        token: loginResponse.token,
        userId: loginResponse.userId,
        name: loginResponse.name,
        role: loginResponse.role.toBackendString(),
      );

      _session = UserSession(
        token: loginResponse.token,
        userId: loginResponse.userId,
        name: loginResponse.name,
        role: loginResponse.role,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred during login.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logs out the user and clears all local credentials.
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _storageService.clearSession();
    _session = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Clears any transient error message.
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}
