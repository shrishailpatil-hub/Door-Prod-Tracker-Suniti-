import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/models/auth/user_role.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/fake_secure_storage.dart';

void main() {
  late FakeFlutterSecureStorage fakeStorage;
  late SecureStorageService storageService;

  setUp(() {
    fakeStorage = FakeFlutterSecureStorage();
    storageService = SecureStorageService(storage: fakeStorage);
  });

  group('AuthProvider Tests', () {
    test('Initial state is not initialized and not authenticated', () {
      final authProvider = AuthProvider(storageService: storageService);

      expect(authProvider.isInitialized, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.session, isNull);
      expect(authProvider.isLoading, isFalse);
    });

    test('initialize restores session if stored credentials exist', () async {
      await storageService.saveSession(
        token: 'stored-token',
        userId: 'uid-456',
        name: 'Floor Manager',
        role: 'MANAGER',
      );

      final authProvider = AuthProvider(storageService: storageService);

      await authProvider.initialize();

      expect(authProvider.isInitialized, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.session?.name, 'Floor Manager');
      expect(authProvider.session?.role, UserRole.manager);
    });

    test('initialize stays unauthenticated if storage is empty', () async {
      final authProvider = AuthProvider(storageService: storageService);

      await authProvider.initialize();

      expect(authProvider.isInitialized, isTrue);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.session, isNull);
    });

    test('login success saves session and notifies listeners', () async {
      final mockClient = MockClient((request) async {
        expect(jsonDecode(request.body), {
          'email': 'worker@example.com',
          'password': 'password123',
        });
        return http.Response(
          jsonEncode({
            'token': 'jwt-response-token',
            'userId': 'user-uuid-999',
            'name': 'Assembly Worker',
            'role': 'WORKER',
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: 'http://example.com/api',
        storageService: storageService,
        httpClient: mockClient,
      );

      final authProvider = AuthProvider(
        apiClient: apiClient,
        storageService: storageService,
      );

      final success = await authProvider.login(
        email: 'worker@example.com',
        password: 'password123',
      );

      expect(success, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.session?.name, 'Assembly Worker');
      expect(authProvider.session?.role, UserRole.worker);
      expect(await storageService.getToken(), 'jwt-response-token');
      expect(authProvider.errorMessage, isNull);
    });

    test(
      'login failure sets error message and leaves session unauthenticated',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'status': 401,
              'message': 'Invalid username or password',
            }),
            401,
          );
        });

        final apiClient = ApiClient(
          baseUrl: 'http://example.com/api',
          storageService: storageService,
          httpClient: mockClient,
        );

        final authProvider = AuthProvider(
          apiClient: apiClient,
          storageService: storageService,
        );

        final success = await authProvider.login(
          email: 'worker@example.com',
          password: 'wrongpassword',
        );

        expect(success, isFalse);
        expect(authProvider.isAuthenticated, isFalse);
        expect(authProvider.session, isNull);
        expect(authProvider.errorMessage, 'Invalid username or password');
      },
    );

    test('logout clears session and storage', () async {
      await storageService.saveSession(
        token: 'stored-token',
        userId: 'uid-456',
        name: 'Floor Manager',
        role: 'MANAGER',
      );

      final authProvider = AuthProvider(storageService: storageService);

      await authProvider.initialize();
      expect(authProvider.isAuthenticated, isTrue);

      await authProvider.logout();

      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.session, isNull);
      expect(await storageService.hasToken(), isFalse);
    });
  });
}
