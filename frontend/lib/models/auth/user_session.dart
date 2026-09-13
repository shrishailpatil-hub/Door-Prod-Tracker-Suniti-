import 'user_role.dart';

/// Represents an active authenticated session in memory.
class UserSession {
  final String token;
  final String userId;
  final String name;
  final UserRole role;

  const UserSession({
    required this.token,
    required this.userId,
    required this.name,
    required this.role,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isManager => role == UserRole.manager;
  bool get isWorker => role == UserRole.worker;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSession &&
          runtimeType == other.runtimeType &&
          token == other.token &&
          userId == other.userId &&
          name == other.name &&
          role == other.role;

  @override
  int get hashCode =>
      token.hashCode ^ userId.hashCode ^ name.hashCode ^ role.hashCode;

  @override
  String toString() =>
      'UserSession(userId: $userId, name: $name, role: ${role.name})';
}
