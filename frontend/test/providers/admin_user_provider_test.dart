// GENERATED TEST FILE - DO NOT MODIFY MANUALLY
// Test for AdminUserProvider.updateUserStatus behavior

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:frontend/providers/admin_user_provider.dart';
import 'package:frontend/services/admin_user_service.dart';
import 'package:frontend/models/auth/app_user.dart';
import 'package:frontend/models/auth/user_role.dart';
import 'package:frontend/core/errors/api_exception.dart';

class MockAdminUserService extends Mock implements AdminUserService {}

void main() {
  setUpAll(() {
    registerFallbackValue(UserRole.worker);
  });

  group('AdminUserProvider.updateUserStatus', () {
    late MockAdminUserService mockService;
    late AdminUserProvider provider;

    setUp(() {
      mockService = MockAdminUserService();
      provider = AdminUserProvider(userService: mockService);
    });

    test('sets isUpdating true during call and resets after success', () async {
      const user = AppUser(
        id: 'u1',
        name: 'Test',
        email: 'test@example.com',
        role: UserRole.admin,
        isActive: true,
      );
      when(() => mockService.updateUserStatus(id: any(named: 'id'), isActive: any(named: 'isActive')))
          .thenAnswer((_) async => user);
      when(() => mockService.getUsers()).thenAnswer((_) async => [user]);

      final future = provider.updateUserStatus(id: 'u1', isActive: false);
      expect(provider.isUpdating, isTrue);
      await future;
      expect(provider.isUpdating, isFalse);
      verify(() => mockService.updateUserStatus(id: 'u1', isActive: false)).called(1);
      verify(() => mockService.getUsers()).called(1);

    });

    test('prevents duplicate calls when already updating', () async {
      // Simulate a delayed response to keep _isUpdating true on second call
      when(() => mockService.updateUserStatus(id: any(named: 'id'), isActive: any(named: 'isActive')))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return const AppUser(
          id: 'u1',
          name: 'Test',
          email: 'test@example.com',
          role: UserRole.admin,
          isActive: true,
        );
      });
      when(() => mockService.getUsers()).thenAnswer((_) async => []);

      // First call starts and sets _isUpdating true
      final f1 = provider.updateUserStatus(id: 'u1', isActive: false);
      // Second call should be ignored because _isUpdating is true
      final f2 = provider.updateUserStatus(id: 'u1', isActive: true);

      await Future.wait([f1, f2]);

      // Only one call to service should have been made, and exactly one refresh triggered
      verify(() => mockService.updateUserStatus(id: any(named: 'id'), isActive: any(named: 'isActive'))).called(1);
      verify(() => mockService.getUsers()).called(1);
    });

    test('captures ApiException message into updateErrorMessage and does not refresh users', () async {
      when(() => mockService.updateUserStatus(id: any(named: 'id'), isActive: any(named: 'isActive')))
          .thenThrow(const ApiException(message: 'Backend error'));

      await provider.updateUserStatus(id: 'u1', isActive: false);
      expect(provider.updateErrorMessage, 'Backend error');
      verifyNever(() => mockService.getUsers());
    });
  });

  group('AdminUserProvider.createUser', () {
    late MockAdminUserService mockService;
    late AdminUserProvider provider;

    setUp(() {
      mockService = MockAdminUserService();
      provider = AdminUserProvider(userService: mockService);
    });

    test('sets isCreating true during call, resets after success, and refreshes user list exactly once', () async {
      const user = AppUser(
        id: 'u2',
        name: 'New User',
        email: 'new@doorcorp.com',
        role: UserRole.worker,
        isActive: true,
      );
      when(() => mockService.createUser(
            name: any(named: 'name'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            role: any(named: 'role'),
          )).thenAnswer((_) async => user);
      when(() => mockService.getUsers()).thenAnswer((_) async => [user]);

      final future = provider.createUser(
        name: 'New User',
        email: 'new@doorcorp.com',
        password: 'password123',
        role: UserRole.worker,
      );
      expect(provider.isCreating, isTrue);
      final success = await future;
      expect(success, isTrue);
      expect(provider.isCreating, isFalse);
      expect(provider.createErrorMessage, isNull);

      verify(() => mockService.createUser(
            name: 'New User',
            email: 'new@doorcorp.com',
            password: 'password123',
            role: UserRole.worker,
          )).called(1);
      verify(() => mockService.getUsers()).called(1);
    });

    test('prevents duplicate calls when already creating', () async {
      when(() => mockService.createUser(
            name: any(named: 'name'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            role: any(named: 'role'),
          )).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return const AppUser(
          id: 'u2',
          name: 'New User',
          email: 'new@doorcorp.com',
          role: UserRole.worker,
          isActive: true,
        );
      });
      when(() => mockService.getUsers()).thenAnswer((_) async => []);

      final f1 = provider.createUser(
        name: 'User 1',
        email: 'u1@test.com',
        password: 'password123',
        role: UserRole.worker,
      );
      final f2 = provider.createUser(
        name: 'User 2',
        email: 'u2@test.com',
        password: 'password123',
        role: UserRole.worker,
      );

      final results = await Future.wait([f1, f2]);
      expect(results[0], isTrue);
      expect(results[1], isFalse);

      verify(() => mockService.createUser(
            name: any(named: 'name'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            role: any(named: 'role'),
          )).called(1);
      verify(() => mockService.getUsers()).called(1);
    });

    test('captures ApiException message into createErrorMessage and returns false without refresh', () async {
      when(() => mockService.createUser(
            name: any(named: 'name'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            role: any(named: 'role'),
          )).thenThrow(const ApiException(message: 'Email already exists'));

      final success = await provider.createUser(
        name: 'New User',
        email: 'existing@doorcorp.com',
        password: 'password123',
        role: UserRole.worker,
      );

      expect(success, isFalse);
      expect(provider.createErrorMessage, 'Email already exists');
      expect(provider.isCreating, isFalse);
      verifyNever(() => mockService.getUsers());
    });
  });
}
