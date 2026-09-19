import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/services/fcm_service.dart';
import 'package:frontend/core/network/api_client.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FcmService', () {
    late MockApiClient mockApiClient;

    setUp(() {
      mockApiClient = MockApiClient();
    });

    test('initialize completes without throwing', () async {
      // Mock the post call to succeed.
      when(() => mockApiClient.post(any(), body: any(named: 'body'), authenticated: any(named: 'authenticated')))
          .thenAnswer((_) async => {});

      // Call initialize; any internal Firebase errors are caught.
      await FcmService.initialize(mockApiClient);
      // If no exception, test passes.
    });
  });
}
