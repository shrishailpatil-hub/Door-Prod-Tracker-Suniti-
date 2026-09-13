import 'user_role.dart';

/// DTO representing the response payload from POST /api/auth/login.
class LoginResponse {
  final String token;
  final String userId;
  final String name;
  final UserRole role;

  const LoginResponse({
    required this.token,
    required this.userId,
    required this.name,
    required this.role,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      role: UserRole.fromString(json['role'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'userId': userId,
      'name': name,
      'role': role.toBackendString(),
    };
  }
}
