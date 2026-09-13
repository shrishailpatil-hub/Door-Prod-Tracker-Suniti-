import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/auth/login_response.dart';
import 'package:frontend/models/auth/user_role.dart';
import 'package:frontend/models/auth/user_session.dart';

void main() {
  group('UserRole Enum Tests', () {
    test('fromString parses correctly for all roles', () {
      expect(UserRole.fromString('ADMIN'), UserRole.admin);
      expect(UserRole.fromString('admin'), UserRole.admin);
      expect(UserRole.fromString('MANAGER'), UserRole.manager);
      expect(UserRole.fromString('manager'), UserRole.manager);
      expect(UserRole.fromString('WORKER'), UserRole.worker);
      expect(UserRole.fromString('worker'), UserRole.worker);
    });

    test('fromString throws ArgumentError on unknown role', () {
      expect(() => UserRole.fromString('SUPERUSER'), throwsArgumentError);
    });

    test('toBackendString converts to uppercase string', () {
      expect(UserRole.admin.toBackendString(), 'ADMIN');
      expect(UserRole.manager.toBackendString(), 'MANAGER');
      expect(UserRole.worker.toBackendString(), 'WORKER');
    });

    test('displayName returns user-friendly label', () {
      expect(UserRole.admin.displayName, 'Administrator');
      expect(UserRole.manager.displayName, 'Floor Manager');
      expect(UserRole.worker.displayName, 'Assembly Worker');
    });
  });

  group('LoginResponse DTO Tests', () {
    test('fromJson deserializes JSON map accurately', () {
      final json = {
        'token': 'mock-jwt-token-xyz',
        'userId': '123e4567-e89b-12d3-a456-426614174000',
        'name': 'John Worker',
        'role': 'WORKER',
      };

      final response = LoginResponse.fromJson(json);

      expect(response.token, 'mock-jwt-token-xyz');
      expect(response.userId, '123e4567-e89b-12d3-a456-426614174000');
      expect(response.name, 'John Worker');
      expect(response.role, UserRole.worker);
    });

    test('toJson serializes to JSON map accurately', () {
      const response = LoginResponse(
        token: 'token-abc',
        userId: 'user-uuid-1',
        name: 'Manager Bob',
        role: UserRole.manager,
      );

      final json = response.toJson();

      expect(json['token'], 'token-abc');
      expect(json['userId'], 'user-uuid-1');
      expect(json['name'], 'Manager Bob');
      expect(json['role'], 'MANAGER');
    });
  });

  group('UserSession Model Tests', () {
    test('Role helper getters return expected booleans', () {
      const adminSession = UserSession(
        token: 'token',
        userId: 'uid-1',
        name: 'Admin',
        role: UserRole.admin,
      );
      expect(adminSession.isAdmin, isTrue);
      expect(adminSession.isManager, isFalse);
      expect(adminSession.isWorker, isFalse);

      const workerSession = UserSession(
        token: 'token',
        userId: 'uid-2',
        name: 'Worker',
        role: UserRole.worker,
      );
      expect(workerSession.isAdmin, isFalse);
      expect(workerSession.isManager, isFalse);
      expect(workerSession.isWorker, isTrue);

      const managerSession = UserSession(
        token: 'token',
        userId: 'uid-3',
        name: 'Manager',
        role: UserRole.manager,
      );
      expect(managerSession.isAdmin, isFalse);
      expect(managerSession.isManager, isTrue);
      expect(managerSession.isWorker, isFalse);
    });

    test('Equality and hash code work for equal instances', () {
      const s1 = UserSession(
        token: 'token-1',
        userId: 'uid-1',
        name: 'User 1',
        role: UserRole.worker,
      );
      const s2 = UserSession(
        token: 'token-1',
        userId: 'uid-1',
        name: 'User 1',
        role: UserRole.worker,
      );

      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
    });
  });
}
