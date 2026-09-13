import '../core/config/api_config.dart';
import '../core/errors/api_exception.dart';
import '../core/network/api_client.dart';
import '../models/auth/app_user.dart';
import '../models/auth/user_role.dart';


class AdminUserService {
  final ApiClient _apiClient;

  AdminUserService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Fetches all system users for the admin user management view.
  Future<List<AppUser>> getUsers() async {
    final response = await _apiClient.get(ApiConfig.adminUsersEndpoint);
    if (response is! List) {
      throw const ApiException(
        message: 'Unexpected response format for users',
      );
    }
    return response.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Updates an existing user.
  Future<AppUser> updateUser({
    required String id,
    required String name,
    required String email,
    required UserRole role,
  }) async {
    final body = {
      'name': name,
      'email': email,
      'role': role.toBackendString(),
    };
    final response = await _apiClient.put('${ApiConfig.adminUsersEndpoint}/$id', body: body);
    return AppUser.fromJson(response as Map<String, dynamic>);
  }

  /// Updates the active status of a user.
  Future<AppUser> updateUserStatus({
    required String id,
    required bool isActive,
  }) async {
    final body = {
      'isActive': isActive,
    };
    final response = await _apiClient.patch('${ApiConfig.adminUsersEndpoint}/$id/status', body: body);
    return AppUser.fromJson(response as Map<String, dynamic>);
  }

  /// Creates a new user.
  Future<AppUser> createUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final body = {
      'name': name,
      'email': email,
      'password': password,
      'role': role.toBackendString(),
    };
    final response = await _apiClient.post(ApiConfig.adminUsersEndpoint, body: body);
    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'Unexpected response format for created user',
      );
    }
    return AppUser.fromJson(response);
  }
}
