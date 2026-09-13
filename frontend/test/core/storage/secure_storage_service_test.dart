import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import '../../helpers/fake_secure_storage.dart';

void main() {
  late FakeFlutterSecureStorage fakeStorage;
  late SecureStorageService service;

  setUp(() {
    fakeStorage = FakeFlutterSecureStorage();
    service = SecureStorageService(storage: fakeStorage);
  });

  group('SecureStorageService Tests', () {
    test('initially has no token or session', () async {
      expect(await service.getToken(), isNull);
      expect(await service.getUserId(), isNull);
      expect(await service.getUserName(), isNull);
      expect(await service.getUserRole(), isNull);
      expect(await service.hasToken(), isFalse);
    });

    test('saveSession stores all credentials correctly', () async {
      await service.saveSession(
        token: 'sample-jwt-token',
        userId: 'uuid-1234',
        name: 'Worker Dave',
        role: 'WORKER',
      );

      expect(await service.getToken(), 'sample-jwt-token');
      expect(await service.getUserId(), 'uuid-1234');
      expect(await service.getUserName(), 'Worker Dave');
      expect(await service.getUserRole(), 'WORKER');
      expect(await service.hasToken(), isTrue);
    });

    test('clearSession removes all credentials', () async {
      await service.saveSession(
        token: 'sample-jwt-token',
        userId: 'uuid-1234',
        name: 'Worker Dave',
        role: 'WORKER',
      );
      expect(await service.hasToken(), isTrue);

      await service.clearSession();

      expect(await service.getToken(), isNull);
      expect(await service.getUserId(), isNull);
      expect(await service.getUserName(), isNull);
      expect(await service.getUserRole(), isNull);
      expect(await service.hasToken(), isFalse);
    });
  });
}
