import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service responsible for secure persistence of authentication credentials and user profile info.
class SecureStorageService {
  final FlutterSecureStorage _storage;

  static const String _keyToken = 'jwt_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';
  static const String _keyUserRole = 'user_role';

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Persists full user session upon successful login.
  Future<void> saveSession({
    required String token,
    required String userId,
    required String name,
    required String role,
  }) async {
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyUserId, value: userId);
    await _storage.write(key: _keyUserName, value: name);
    await _storage.write(key: _keyUserRole, value: role);
  }

  /// Retrieves the persisted JWT token.
  Future<String?> getToken() async {
    return _storage.read(key: _keyToken);
  }

  /// Retrieves the persisted user ID.
  Future<String?> getUserId() async {
    return _storage.read(key: _keyUserId);
  }

  /// Retrieves the persisted user name.
  Future<String?> getUserName() async {
    return _storage.read(key: _keyUserName);
  }

  /// Retrieves the persisted user role.
  Future<String?> getUserRole() async {
    return _storage.read(key: _keyUserRole);
  }

  /// Checks if a valid token is stored.
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Clears all session keys on logout.
  Future<void> clearSession() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyUserName);
    await _storage.delete(key: _keyUserRole);
  }
}
