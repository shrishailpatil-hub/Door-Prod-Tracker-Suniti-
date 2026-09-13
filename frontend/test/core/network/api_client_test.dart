import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/errors/api_exception.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/fake_secure_storage.dart';

void main() {
  late FakeFlutterSecureStorage fakeStorage;
  late SecureStorageService storageService;

  setUp(() {
    fakeStorage = FakeFlutterSecureStorage();
    storageService = SecureStorageService(storage: fakeStorage);
  });

  group('ApiClient Tests', () {
    test(
      'GET request attaches Bearer token when authenticated is true',
      () async {
        await storageService.saveSession(
          token: 'auth-jwt-123',
          userId: 'u1',
          name: 'User 1',
          role: 'WORKER',
        );

        String? authHeaderReceived;
        final mockClient = MockClient((request) async {
          authHeaderReceived = request.headers['Authorization'];
          return http.Response(jsonEncode({'success': true}), 200);
        });

        final client = ApiClient(
          baseUrl: 'http://example.com/api',
          storageService: storageService,
          httpClient: mockClient,
        );

        final result = await client.get('/test-endpoint');

        expect(authHeaderReceived, 'Bearer auth-jwt-123');
        expect(result['success'], isTrue);
      },
    );

    test(
      'POST request sends serialized json body and receives parsed response',
      () async {
        Map<String, dynamic>? receivedBody;
        final mockClient = MockClient((request) async {
          receivedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'createdId': '123'}), 201);
        });

        final client = ApiClient(
          baseUrl: 'http://example.com/api',
          storageService: storageService,
          httpClient: mockClient,
        );

        final result = await client.post(
          '/items',
          body: {'name': 'New Door Process'},
          authenticated: false,
        );

        expect(receivedBody?['name'], 'New Door Process');
        expect(result['createdId'], '123');
      },
    );

    test('Handles query parameters in GET request', () async {
      Uri? requestedUri;
      final mockClient = MockClient((request) async {
        requestedUri = request.url;
        return http.Response(jsonEncode([]), 200);
      });

      final client = ApiClient(
        baseUrl: 'http://example.com/api',
        storageService: storageService,
        httpClient: mockClient,
      );

      await client.get(
        '/items',
        queryParams: {'status': 'IN_PROGRESS', 'limit': 10},
      );

      expect(requestedUri?.queryParameters['status'], 'IN_PROGRESS');
      expect(requestedUri?.queryParameters['limit'], '10');
    });

    test(
      'Throws ApiException with backend error message on 400 Bad Request',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'status': 400, 'message': 'Job number already exists'}),
            400,
          );
        });

        final client = ApiClient(
          baseUrl: 'http://example.com/api',
          storageService: storageService,
          httpClient: mockClient,
        );

        expect(
          () => client.post('/jobs', body: {}),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having(
                  (e) => e.message,
                  'message',
                  'Job number already exists',
                ),
          ),
        );
      },
    );

    test(
      'Throws ApiException with 401 default message when body is empty',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('', 401);
        });

        final client = ApiClient(
          baseUrl: 'http://example.com/api',
          storageService: storageService,
          httpClient: mockClient,
        );

        expect(
          () => client.get('/protected'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 401)
                .having(
                  (e) => e.message,
                  'message',
                  contains('Session expired'),
                ),
          ),
        );
      },
    );

    test('Throws ApiException on connection timeout', () async {
      final mockClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return http.Response('{}', 200);
      });

      final client = ApiClient(
        baseUrl: 'http://example.com/api',
        storageService: storageService,
        httpClient: mockClient,
        timeout: const Duration(milliseconds: 10),
      );

      expect(
        () => client.get('/slow'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Connection timed out'),
          ),
        ),
      );
    });
  });
}
