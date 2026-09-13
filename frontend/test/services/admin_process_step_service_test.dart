import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:frontend/core/config/api_config.dart';
import 'package:frontend/core/errors/api_exception.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/services/admin_process_step_service.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  setUpAll(() {
    registerFallbackValue({});
  });

  group('AdminProcessStepService.fetchProcessSteps', () {
    late MockApiClient mockApiClient;
    late AdminProcessStepService service;

    setUp(() {
      mockApiClient = MockApiClient();
      service = AdminProcessStepService(apiClient: mockApiClient);
    });

    test('sends GET to exact endpoint, parses JSON array, and preserves both active and inactive steps', () async {
      final mockResponse = [
        {
          'id': 'step-1',
          'name': 'Cutting',
          'stepOrder': 1,
          'isActive': true,
          'createdAt': '2026-09-10T10:00:00.000Z',
          'updatedAt': '2026-09-10T10:00:00.000Z',
        },
        {
          'id': 'step-2',
          'name': 'Old Welding',
          'stepOrder': 2,
          'isActive': false,
          'createdAt': '2026-08-01T10:00:00.000Z',
          'updatedAt': '2026-08-02T10:00:00.000Z',
        },
      ];

      when(() => mockApiClient.get(ApiConfig.adminProcessStepsEndpoint))
          .thenAnswer((_) async => mockResponse);

      final result = await service.fetchProcessSteps();

      verify(() => mockApiClient.get(ApiConfig.adminProcessStepsEndpoint)).called(1);
      expect(result.length, 2);
      expect(result[0].id, 'step-1');
      expect(result[0].name, 'Cutting');
      expect(result[0].stepOrder, 1);
      expect(result[0].isActive, isTrue);

      expect(result[1].id, 'step-2');
      expect(result[1].name, 'Old Welding');
      expect(result[1].stepOrder, 2);
      expect(result[1].isActive, isFalse);
    });

    test('throws ApiException when response is not a List', () async {
      when(() => mockApiClient.get(ApiConfig.adminProcessStepsEndpoint))
          .thenAnswer((_) async => {'error': 'Not a list'});

      expect(
        () => service.fetchProcessSteps(),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Unexpected response format for process steps',
        )),
      );
    });
  });

  group('AdminProcessStepService.createProcessStep', () {
    late MockApiClient mockApiClient;
    late AdminProcessStepService service;

    setUp(() {
      mockApiClient = MockApiClient();
      service = AdminProcessStepService(apiClient: mockApiClient);
    });

    test('sends POST to exact endpoint with exact request body and parses response correctly', () async {
      final mockResponse = {
        'id': 'new-step-123',
        'name': 'Welding',
        'stepOrder': 2,
        'isActive': true,
        'createdAt': '2026-09-10T10:00:00.000Z',
        'updatedAt': '2026-09-10T10:00:00.000Z',
      };

      when(() => mockApiClient.post(ApiConfig.adminProcessStepsEndpoint, body: any(named: 'body')))
          .thenAnswer((_) async => mockResponse);

      final result = await service.createProcessStep(
        name: 'Welding',
        stepOrder: 2,
      );

      final captured = verify(() => mockApiClient.post(
            ApiConfig.adminProcessStepsEndpoint,
            body: captureAny(named: 'body'),
          )).captured;

      expect(captured.length, 1);
      expect(captured.first, {
        'name': 'Welding',
        'stepOrder': 2,
      });

      expect(result.id, 'new-step-123');
      expect(result.name, 'Welding');
      expect(result.stepOrder, 2);
      expect(result.isActive, isTrue);
    });
  });

  group('AdminProcessStepService.updateProcessStep', () {
    late MockApiClient mockApiClient;
    late AdminProcessStepService service;

    setUp(() {
      mockApiClient = MockApiClient();
      service = AdminProcessStepService(apiClient: mockApiClient);
    });

    test('sends PUT to exact endpoint with correct ID and body and parses response correctly', () async {
      const stepId = 'step-to-update';
      final mockResponse = {
        'id': stepId,
        'name': 'Framing & Sanding',
        'stepOrder': 1,
        'isActive': true,
        'createdAt': '2026-09-10T10:00:00.000Z',
        'updatedAt': '2026-09-10T12:00:00.000Z',
      };

      when(() => mockApiClient.put(
            '${ApiConfig.adminProcessStepsEndpoint}/$stepId',
            body: any(named: 'body'),
          )).thenAnswer((_) async => mockResponse);

      final result = await service.updateProcessStep(
        id: stepId,
        name: 'Framing & Sanding',
        stepOrder: 1,
      );

      final captured = verify(() => mockApiClient.put(
            '${ApiConfig.adminProcessStepsEndpoint}/$stepId',
            body: captureAny(named: 'body'),
          )).captured;

      expect(captured.length, 1);
      expect(captured.first, {
        'name': 'Framing & Sanding',
        'stepOrder': 1,
      });

      expect(result.id, stepId);
      expect(result.name, 'Framing & Sanding');
      expect(result.stepOrder, 1);
      expect(result.isActive, isTrue);
    });
  });

  group('AdminProcessStepService.deactivateProcessStep', () {
    late MockApiClient mockApiClient;
    late AdminProcessStepService service;

    setUp(() {
      mockApiClient = MockApiClient();
      service = AdminProcessStepService(apiClient: mockApiClient);
    });

    test('sends DELETE to exact endpoint with correct ID, sends no request body, and returns step with isActive: false', () async {
      const stepId = 'step-to-deactivate';
      final mockResponse = {
        'id': stepId,
        'name': 'Obsolete Step',
        'stepOrder': 3,
        'isActive': false,
        'createdAt': '2026-09-10T10:00:00.000Z',
        'updatedAt': '2026-09-10T13:00:00.000Z',
      };

      when(() => mockApiClient.delete('${ApiConfig.adminProcessStepsEndpoint}/$stepId'))
          .thenAnswer((_) async => mockResponse);

      final result = await service.deactivateProcessStep(stepId);

      verify(() => mockApiClient.delete('${ApiConfig.adminProcessStepsEndpoint}/$stepId')).called(1);

      expect(result.id, stepId);
      expect(result.name, 'Obsolete Step');
      expect(result.isActive, isFalse);
    });
  });

  group('AdminProcessStepService.reactivateProcessStep', () {
    late MockApiClient mockApiClient;
    late AdminProcessStepService service;

    setUp(() {
      mockApiClient = MockApiClient();
      service = AdminProcessStepService(apiClient: mockApiClient);
    });

    test('sends POST to exact reactivate endpoint and returns step with isActive: true', () async {
      const stepId = 'step-to-reactivate';
      final mockResponse = {
        'id': stepId,
        'name': 'Reactivated Step',
        'stepOrder': 4,
        'isActive': true,
        'createdAt': '2026-09-10T10:00:00.000Z',
        'updatedAt': '2026-09-12T18:00:00.000Z',
      };

      when(() => mockApiClient.post('${ApiConfig.adminProcessStepsEndpoint}/$stepId/reactivate'))
          .thenAnswer((_) async => mockResponse);

      final result = await service.reactivateProcessStep(stepId);

      verify(() => mockApiClient.post('${ApiConfig.adminProcessStepsEndpoint}/$stepId/reactivate')).called(1);

      expect(result.id, stepId);
      expect(result.name, 'Reactivated Step');
      expect(result.stepOrder, 4);
      expect(result.isActive, isTrue);
    });
  });

  group('AdminProcessStepService Error Handling', () {
    late MockApiClient mockApiClient;
    late AdminProcessStepService service;

    setUp(() {
      mockApiClient = MockApiClient();
      service = AdminProcessStepService(apiClient: mockApiClient);
    });

    test('preserves 400 Bad Request error message on createProcessStep', () async {
      when(() => mockApiClient.post(ApiConfig.adminProcessStepsEndpoint, body: any(named: 'body')))
          .thenThrow(const ApiException(
        statusCode: 400,
        message: 'Step order out of allowed range',
      ));

      expect(
        () => service.createProcessStep(name: 'Invalid Step', stepOrder: 999),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message', 'Step order out of allowed range')),
      );
    });

    test('preserves 409 Conflict error message on duplicate active step name', () async {
      when(() => mockApiClient.post(ApiConfig.adminProcessStepsEndpoint, body: any(named: 'body')))
          .thenThrow(const ApiException(
        statusCode: 409,
        message: 'Active process step name already exists',
      ));

      expect(
        () => service.createProcessStep(name: 'Cutting', stepOrder: 1),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.message, 'message', 'Active process step name already exists')),
      );
    });

    test('preserves 404 Not Found error message on updateProcessStep', () async {
      const missingId = 'non-existent-step';
      when(() => mockApiClient.put(
            '${ApiConfig.adminProcessStepsEndpoint}/$missingId',
            body: any(named: 'body'),
          )).thenThrow(const ApiException(
        statusCode: 404,
        message: 'Process step not found',
      ));

      expect(
        () => service.updateProcessStep(id: missingId, name: 'Renamed', stepOrder: 1),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', 'Process step not found')),
      );
    });

    test('preserves 404 Not Found error message on deactivateProcessStep', () async {
      const missingId = 'non-existent-step';
      when(() => mockApiClient.delete('${ApiConfig.adminProcessStepsEndpoint}/$missingId'))
          .thenThrow(const ApiException(
        statusCode: 404,
        message: 'Process step not found',
      ));

      expect(
        () => service.deactivateProcessStep(missingId),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', 'Process step not found')),
      );
    });
  });
}
