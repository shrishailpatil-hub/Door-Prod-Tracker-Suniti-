// Test for AdminUserService.updateUserStatus

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:frontend/services/admin_user_service.dart';
import 'package:frontend/models/auth/app_user.dart';
import 'package:frontend/models/auth/user_role.dart';
import 'package:frontend/core/config/api_config.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/errors/api_exception.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  setUpAll(() {
    registerFallbackValue({});
  });

  group('AdminUserService.updateUserStatus', () {
    late MockApiClient mockApiClient;
    late AdminUserService service;

    setUp(() {
      mockApiClient = MockApiClient();
      service = AdminUserService(apiClient: mockApiClient);
    });

    test('sends PATCH with correct endpoint and body and parses response', () async {
      const userId = 'user-123';
      const isActive = false;
      final mockResponse = {
        'id': userId,
        'name': 'Test User',
        'email': 'test@example.com',
        'role': 'ADMIN',
        'isActive': isActive,
      };

      when(() => mockApiClient.patch('${ApiConfig.adminUsersEndpoint}/$userId/status', body: any(named: 'body')))
          .thenAnswer((_) async => mockResponse);

      final result = await service.updateUserStatus(id: userId, isActive: isActive);

      final captured = verify(() => mockApiClient.patch('${ApiConfig.adminUsersEndpoint}/$userId/status', body: captureAny(named: 'body'))).captured;
      expect(captured.length, 1);
      expect(captured.first, {'isActive': isActive});

      expect(result, isA<AppUser>());
      expect(result.id, userId);
      expect(result.isActive, isActive);
      expect(result.role, UserRole.admin);
    });
  });

  group('AdminUserService.createUser', () {
    late MockApiClient mockApiClient;
    late AdminUserService service;

    setUp(() {
      mockApiClient = MockApiClient();
      service = AdminUserService(apiClient: mockApiClient);
    });

    test('sends POST with correct endpoint and serialized body and parses AppUser response', () async {
      final mockResponse = {
        'id': 'new-user-id',
        'name': 'Dave Worker',
        'email': 'dave@doorcorp.com',
        'role': 'WORKER',
        'isActive': true,
      };

      when(() => mockApiClient.post(ApiConfig.adminUsersEndpoint, body: any(named: 'body')))
          .thenAnswer((_) async => mockResponse);

      final result = await service.createUser(
        name: 'Dave Worker',
        email: 'dave@doorcorp.com',
        password: 'password123',
        role: UserRole.worker,
      );

      final captured = verify(() => mockApiClient.post(
            ApiConfig.adminUsersEndpoint,
            body: captureAny(named: 'body'),
          )).captured;

      expect(captured.length, 1);
      expect(captured.first, {
        'name': 'Dave Worker',
        'email': 'dave@doorcorp.com',
        'password': 'password123',
        'role': 'WORKER',
      });

      expect(result.id, 'new-user-id');
      expect(result.name, 'Dave Worker');
      expect(result.email, 'dave@doorcorp.com');
      expect(result.role, UserRole.worker);
      expect(result.isActive, isTrue);
    });

    test('propagates ApiException on failure', () async {
      when(() => mockApiClient.post(ApiConfig.adminUsersEndpoint, body: any(named: 'body')))
          .thenThrow(const ApiException(statusCode: 400, message: 'Email already exists'));

      expect(
        () => service.createUser(
          name: 'Dave Worker',
          email: 'dave@doorcorp.com',
          password: 'password123',
          role: UserRole.worker,
        ),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Email already exists')),
      );
    });
  });
}
