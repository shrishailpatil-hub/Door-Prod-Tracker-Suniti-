/// Represents the user role within the system.
enum UserRole {
  admin,
  manager,
  worker;

  static UserRole fromString(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return UserRole.admin;
      case 'MANAGER':
        return UserRole.manager;
      case 'WORKER':
        return UserRole.worker;
      default:
        throw ArgumentError('Unknown role: $role');
    }
  }

  String toBackendString() {
    switch (this) {
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.manager:
        return 'MANAGER';
      case UserRole.worker:
        return 'WORKER';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.manager:
        return 'Floor Manager';
      case UserRole.worker:
        return 'Assembly Worker';
    }
  }
}
