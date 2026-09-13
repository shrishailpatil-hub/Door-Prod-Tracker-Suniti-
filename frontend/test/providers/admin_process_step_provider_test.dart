import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:frontend/core/errors/api_exception.dart';
import 'package:frontend/models/admin/process_step.dart';
import 'package:frontend/providers/admin_process_step_provider.dart';
import 'package:frontend/services/admin_process_step_service.dart';

class MockAdminProcessStepService extends Mock
    implements AdminProcessStepService {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      ProcessStep(
        id: 'fallback-id',
        name: 'Fallback',
        stepOrder: 1,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  final stepActive1 = ProcessStep(
    id: 's1',
    name: 'Cutting',
    stepOrder: 1,
    isActive: true,
    createdAt: DateTime.parse('2026-09-10T10:00:00.000Z'),
    updatedAt: DateTime.parse('2026-09-10T10:00:00.000Z'),
  );

  final stepActive2 = ProcessStep(
    id: 's2',
    name: 'Welding',
    stepOrder: 2,
    isActive: true,
    createdAt: DateTime.parse('2026-09-10T10:00:00.000Z'),
    updatedAt: DateTime.parse('2026-09-10T10:00:00.000Z'),
  );

  final stepInactive = ProcessStep(
    id: 's3',
    name: 'Old Priming',
    stepOrder: 99,
    isActive: false,
    createdAt: DateTime.parse('2026-09-01T10:00:00.000Z'),
    updatedAt: DateTime.parse('2026-09-05T10:00:00.000Z'),
  );

  group('AdminProcessStepProvider.fetchProcessSteps', () {
    late MockAdminProcessStepService mockService;
    late AdminProcessStepProvider provider;

    setUp(() {
      mockService = MockAdminProcessStepService();
      provider = AdminProcessStepProvider(service: mockService);
    });

    test('1. Successful fetch stores all returned steps', () async {
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepActive1, stepActive2, stepInactive]);

      await provider.fetchProcessSteps();

      expect(provider.steps.length, 3);
      expect(provider.steps.map((s) => s.id), ['s1', 's2', 's3']);
      expect(provider.errorMessage, isNull);
    });

    test('2. Both active and inactive steps remain in steps', () async {
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepActive1, stepInactive]);

      await provider.fetchProcessSteps();

      expect(provider.steps.length, 2);
      expect(provider.steps.any((s) => s.isActive), isTrue);
      expect(provider.steps.any((s) => !s.isActive), isTrue);
    });

    test('3. activeSteps contains only active steps', () async {
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepActive1, stepInactive, stepActive2]);

      await provider.fetchProcessSteps();

      expect(provider.activeSteps.length, 2);
      expect(provider.activeSteps.every((s) => s.isActive), isTrue);
    });

    test('4. activeSteps is sorted by stepOrder ASC', () async {
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepActive2, stepActive1]);

      await provider.fetchProcessSteps();

      expect(provider.activeSteps[0].stepOrder, 1);
      expect(provider.activeSteps[1].stepOrder, 2);
      expect(provider.activeSteps[0].id, 's1');
      expect(provider.activeSteps[1].id, 's2');
    });

    test('5. inactiveSteps contains only inactive steps', () async {
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepActive1, stepInactive]);

      await provider.fetchProcessSteps();

      expect(provider.inactiveSteps.length, 1);
      expect(provider.inactiveSteps.first.id, 's3');
      expect(provider.inactiveSteps.first.isActive, isFalse);
    });

    test('6. Loading state becomes true during fetch and false afterward', () async {
      final states = <bool>[];
      provider.addListener(() {
        states.add(provider.isLoading);
      });

      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepActive1]);

      await provider.fetchProcessSteps();

      expect(states.contains(true), isTrue);
      expect(provider.isLoading, isFalse);
    });

    test('7. API error is exposed through errorMessage', () async {
      when(() => mockService.fetchProcessSteps())
          .thenThrow(const ApiException(statusCode: 500, message: 'Server exploded'));

      await provider.fetchProcessSteps();

      expect(provider.errorMessage, 'Server exploded');
      expect(provider.steps, isEmpty);
    });

    test('8. Loading resets after failure', () async {
      when(() => mockService.fetchProcessSteps())
          .thenThrow(const ApiException(statusCode: 500, message: 'Server exploded'));

      await provider.fetchProcessSteps();

      expect(provider.isLoading, isFalse);
    });

    test('9. Duplicate fetch while already loading is prevented', () async {
      when(() => mockService.fetchProcessSteps()).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return [stepActive1];
      });

      final future1 = provider.fetchProcessSteps();
      final future2 = provider.fetchProcessSteps();

      await Future.wait([future1, future2]);

      verify(() => mockService.fetchProcessSteps()).called(1);
    });
  });

  group('AdminProcessStepProvider.createProcessStep', () {
    late MockAdminProcessStepService mockService;
    late AdminProcessStepProvider provider;

    setUp(() {
      mockService = MockAdminProcessStepService();
      provider = AdminProcessStepProvider(service: mockService);
    });

    test('10. createProcessStep() calls the service with exact name/order', () async {
      when(() => mockService.createProcessStep(
            name: any(named: 'name'),
            stepOrder: any(named: 'stepOrder'),
          )).thenAnswer((_) async => stepActive1);
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepActive1]);

      final success = await provider.createProcessStep(
        name: 'Cutting',
        stepOrder: 1,
      );

      verify(() => mockService.createProcessStep(
            name: 'Cutting',
            stepOrder: 1,
          )).called(1);
      expect(success, isTrue);
    });

    test('11. isCreating becomes true during operation', () async {
      final states = <bool>[];
      provider.addListener(() {
        states.add(provider.isCreating);
      });

      when(() => mockService.createProcessStep(
            name: any(named: 'name'),
            stepOrder: any(named: 'stepOrder'),
          )).thenAnswer((_) async => stepActive1);
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepActive1]);

      await provider.createProcessStep(name: 'Cutting', stepOrder: 1);

      expect(states.contains(true), isTrue);
      expect(provider.isCreating, isFalse);
    });

    test('12. Successful creation triggers exactly ONE list refresh', () async {
      when(() => mockService.createProcessStep(
            name: any(named: 'name'),
            stepOrder: any(named: 'stepOrder'),
          )).thenAnswer((_) async => stepActive1);
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepActive1]);

      await provider.createProcessStep(name: 'Cutting', stepOrder: 1);

      verify(() => mockService.fetchProcessSteps()).called(1);
    });

    test('13. Successful creation returns true', () async {
      when(() => mockService.createProcessStep(
            name: any(named: 'name'),
            stepOrder: any(named: 'stepOrder'),
          )).thenAnswer((_) async => stepActive1);
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepActive1]);

      final result = await provider.createProcessStep(name: 'Cutting', stepOrder: 1);
      expect(result, isTrue);
      expect(provider.createErrorMessage, isNull);
    });

    test('14. Duplicate create submission is prevented', () async {
      when(() => mockService.createProcessStep(
            name: any(named: 'name'),
            stepOrder: any(named: 'stepOrder'),
          )).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return stepActive1;
      });
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepActive1]);

      final future1 = provider.createProcessStep(name: 'Cutting', stepOrder: 1);
      final future2 = provider.createProcessStep(name: 'Cutting', stepOrder: 1);

      final results = await Future.wait([future1, future2]);

      expect(results, [true, false]);
      verify(() => mockService.createProcessStep(name: 'Cutting', stepOrder: 1)).called(1);
    });

    test('15. API failure returns false', () async {
      when(() => mockService.createProcessStep(
            name: any(named: 'name'),
            stepOrder: any(named: 'stepOrder'),
          )).thenThrow(const ApiException(statusCode: 409, message: 'Active process step name already exists'));

      final result = await provider.createProcessStep(name: 'Cutting', stepOrder: 1);
      expect(result, isFalse);
    });

    test('16. API error is exposed through createErrorMessage', () async {
      when(() => mockService.createProcessStep(
            name: any(named: 'name'),
            stepOrder: any(named: 'stepOrder'),
          )).thenThrow(const ApiException(statusCode: 409, message: 'Active process step name already exists'));

      await provider.createProcessStep(name: 'Cutting', stepOrder: 1);

      expect(provider.createErrorMessage, 'Active process step name already exists');
      verifyNever(() => mockService.fetchProcessSteps());
    });

    test('17. isCreating resets after failure', () async {
      when(() => mockService.createProcessStep(
            name: any(named: 'name'),
            stepOrder: any(named: 'stepOrder'),
          )).thenThrow(const ApiException(statusCode: 400, message: 'Invalid order'));

      await provider.createProcessStep(name: 'Cutting', stepOrder: 99);

      expect(provider.isCreating, isFalse);
    });
  });

  group('AdminProcessStepProvider.updateProcessStep', () {
    late MockAdminProcessStepService mockService;
    late AdminProcessStepProvider provider;

    setUp(() {
      mockService = MockAdminProcessStepService();
      provider = AdminProcessStepProvider(service: mockService);
    });

    test('18. updateProcessStep() calls the service with exact id/name/order', () async {
      when(() => mockService.updateProcessStep(
            id: any(named: 'id'),
            name: any(named: 'name'),
            stepOrder: any(named: 'stepOrder'),
          )).thenAnswer((_) async => stepActive1);
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepActive1]);

      final success = await provider.updateProcessStep(
        id: 's1',
        name: 'Cutting New',
        stepOrder: 2,
      );

      verify(() => mockService.updateProcessStep(
            id: 's1',
            name: 'Cutting New',
            stepOrder: 2,
          )).called(1);
      expect(success, isTrue);
    });

    test('19. isUpdating state works correctly', () async {
      final states = <bool>[];
      provider.addListener(() {
        states.add(provider.isUpdating);
      });

      when(() => mockService.updateProcessStep(
            id: any(named: 'id'),
            name: any(named: 'name'),
            stepOrder: any(named: 'stepOrder'),
          )).thenAnswer((_) async => stepActive1);
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepActive1]);

      await provider.updateProcessStep(id: 's1', name: 'Cutting', stepOrder: 1);

      expect(states.contains(true), isTrue);
      expect(provider.isUpdating, isFalse);
    });

    test('20. Successful update triggers exactly ONE refresh', () async {
      when(() => mockService.updateProcessStep(
            id: any(named: 'id'),
            name: any(named: 'name'),
            stepOrder: any(named: 'stepOrder'),
          )).thenAnswer((_) async => stepActive1);
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepActive1]);

      await provider.updateProcessStep(id: 's1', name: 'Cutting', stepOrder: 1);

      verify(() => mockService.fetchProcessSteps()).called(1);
    });

    test('21. Successful update returns true', () async {
      when(() => mockService.updateProcessStep(
            id: any(named: 'id'),
            name: any(named: 'name'),
            stepOrder: any(named: 'stepOrder'),
          )).thenAnswer((_) async => stepActive1);
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepActive1]);

      final result = await provider.updateProcessStep(id: 's1', name: 'Cutting', stepOrder: 1);
      expect(result, isTrue);
      expect(provider.updateErrorMessage, isNull);
    });

    test('22. Duplicate update is prevented', () async {
      when(() => mockService.updateProcessStep(
            id: any(named: 'id'),
            name: any(named: 'name'),
            stepOrder: any(named: 'stepOrder'),
          )).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return stepActive1;
      });
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepActive1]);

      final future1 = provider.updateProcessStep(id: 's1', name: 'Cutting', stepOrder: 1);
      final future2 = provider.updateProcessStep(id: 's1', name: 'Cutting', stepOrder: 1);

      final results = await Future.wait([future1, future2]);

      expect(results, [true, false]);
      verify(() => mockService.updateProcessStep(
            id: 's1',
            name: 'Cutting',
            stepOrder: 1,
          )).called(1);
    });

    test('23. API failure returns false', () async {
      when(() => mockService.updateProcessStep(
            id: any(named: 'id'),
            name: any(named: 'name'),
            stepOrder: any(named: 'stepOrder'),
          )).thenThrow(const ApiException(statusCode: 404, message: 'Process step not found'));

      final result = await provider.updateProcessStep(id: 's1', name: 'Cutting', stepOrder: 1);
      expect(result, isFalse);
    });

    test('24. Error is exposed through updateErrorMessage', () async {
      when(() => mockService.updateProcessStep(
            id: any(named: 'id'),
            name: any(named: 'name'),
            stepOrder: any(named: 'stepOrder'),
          )).thenThrow(const ApiException(statusCode: 404, message: 'Process step not found'));

      await provider.updateProcessStep(id: 's1', name: 'Cutting', stepOrder: 1);

      expect(provider.updateErrorMessage, 'Process step not found');
      verifyNever(() => mockService.fetchProcessSteps());
    });

    test('25. isUpdating resets after failure', () async {
      when(() => mockService.updateProcessStep(
            id: any(named: 'id'),
            name: any(named: 'name'),
            stepOrder: any(named: 'stepOrder'),
          )).thenThrow(const ApiException(statusCode: 500, message: 'Failure'));

      await provider.updateProcessStep(id: 's1', name: 'Cutting', stepOrder: 1);

      expect(provider.isUpdating, isFalse);
    });
  });

  group('AdminProcessStepProvider.deactivateProcessStep', () {
    late MockAdminProcessStepService mockService;
    late AdminProcessStepProvider provider;

    setUp(() {
      mockService = MockAdminProcessStepService();
      provider = AdminProcessStepProvider(service: mockService);
    });

    test('26. deactivateProcessStep() calls the service with the correct ID', () async {
      when(() => mockService.deactivateProcessStep(any()))
          .thenAnswer((_) async => stepInactive);
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepInactive]);

      final success = await provider.deactivateProcessStep('s3');

      verify(() => mockService.deactivateProcessStep('s3')).called(1);
      expect(success, isTrue);
    });

    test('27. isDeactivating state works correctly', () async {
      final states = <bool>[];
      provider.addListener(() {
        states.add(provider.isDeactivating);
      });

      when(() => mockService.deactivateProcessStep(any()))
          .thenAnswer((_) async => stepInactive);
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepInactive]);

      await provider.deactivateProcessStep('s3');

      expect(states.contains(true), isTrue);
      expect(provider.isDeactivating, isFalse);
    });

    test('28. Successful deactivation triggers exactly ONE refresh', () async {
      when(() => mockService.deactivateProcessStep(any()))
          .thenAnswer((_) async => stepInactive);
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepInactive]);

      await provider.deactivateProcessStep('s3');

      verify(() => mockService.fetchProcessSteps()).called(1);
    });

    test('29. Successful deactivation returns true', () async {
      when(() => mockService.deactivateProcessStep(any()))
          .thenAnswer((_) async => stepInactive);
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepInactive]);

      final result = await provider.deactivateProcessStep('s3');

      expect(result, isTrue);
      expect(provider.deactivateErrorMessage, isNull);
    });

    test('30. Duplicate deactivation is prevented', () async {
      when(() => mockService.deactivateProcessStep(any())).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return stepInactive;
      });
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepInactive]);

      final future1 = provider.deactivateProcessStep('s3');
      final future2 = provider.deactivateProcessStep('s3');

      final results = await Future.wait([future1, future2]);

      expect(results, [true, false]);
      verify(() => mockService.deactivateProcessStep('s3')).called(1);
    });

    test('31. API failure returns false', () async {
      when(() => mockService.deactivateProcessStep(any()))
          .thenThrow(const ApiException(statusCode: 404, message: 'Process step not found'));

      final result = await provider.deactivateProcessStep('s3');

      expect(result, isFalse);
    });

    test('32. Error is exposed through deactivateErrorMessage', () async {
      when(() => mockService.deactivateProcessStep(any()))
          .thenThrow(const ApiException(statusCode: 404, message: 'Process step not found'));

      await provider.deactivateProcessStep('s3');

      expect(provider.deactivateErrorMessage, 'Process step not found');
      verifyNever(() => mockService.fetchProcessSteps());
    });

    test('33. isDeactivating resets after failure', () async {
      when(() => mockService.deactivateProcessStep(any()))
          .thenThrow(const ApiException(statusCode: 500, message: 'Failure'));

      await provider.deactivateProcessStep('s3');

      expect(provider.isDeactivating, isFalse);
    });
  });

  group('Mutation Independence', () {
    late MockAdminProcessStepService mockService;
    late AdminProcessStepProvider provider;

    setUp(() {
      mockService = MockAdminProcessStepService();
      provider = AdminProcessStepProvider(service: mockService);
    });

    test('creating does not affect isUpdating or isDeactivating', () async {
      when(() => mockService.createProcessStep(
            name: any(named: 'name'),
            stepOrder: any(named: 'stepOrder'),
          )).thenAnswer((_) async => stepActive1);
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepActive1]);

      expect(provider.isUpdating, isFalse);
      expect(provider.isDeactivating, isFalse);

      await provider.createProcessStep(name: 'Cutting', stepOrder: 1);

      expect(provider.isUpdating, isFalse);
      expect(provider.isDeactivating, isFalse);
    });

    test('updating does not affect isCreating or isDeactivating', () async {
      when(() => mockService.updateProcessStep(
            id: any(named: 'id'),
            name: any(named: 'name'),
            stepOrder: any(named: 'stepOrder'),
          )).thenAnswer((_) async => stepActive1);
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepActive1]);

      expect(provider.isCreating, isFalse);
      expect(provider.isDeactivating, isFalse);

      await provider.updateProcessStep(id: 's1', name: 'Cutting', stepOrder: 1);

      expect(provider.isCreating, isFalse);
      expect(provider.isDeactivating, isFalse);
    });

    test('deactivating does not affect isCreating or isUpdating', () async {
      when(() => mockService.deactivateProcessStep(any()))
          .thenAnswer((_) async => stepInactive);
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepInactive]);

      expect(provider.isCreating, isFalse);
      expect(provider.isUpdating, isFalse);

      await provider.deactivateProcessStep('s3');

      expect(provider.isCreating, isFalse);
      expect(provider.isUpdating, isFalse);
    });

    test('reactivating does not affect isCreating, isUpdating, or isDeactivating', () async {
      when(() => mockService.reactivateProcessStep(any()))
          .thenAnswer((_) async => stepActive1);
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepActive1]);

      expect(provider.isCreating, isFalse);
      expect(provider.isUpdating, isFalse);
      expect(provider.isDeactivating, isFalse);
      expect(provider.isReactivating, isFalse);

      await provider.reactivateProcessStep('s3');

      expect(provider.isCreating, isFalse);
      expect(provider.isUpdating, isFalse);
      expect(provider.isDeactivating, isFalse);
      expect(provider.isReactivating, isFalse);
    });

    test('successful reactivateProcessStep refreshes process steps and returns true', () async {
      when(() => mockService.reactivateProcessStep('s3'))
          .thenAnswer((_) async => stepActive1);
      when(() => mockService.fetchProcessSteps())
          .thenAnswer((_) async => [stepActive1]);

      final result = await provider.reactivateProcessStep('s3');

      verify(() => mockService.reactivateProcessStep('s3')).called(1);
      verify(() => mockService.fetchProcessSteps()).called(1);
      expect(result, isTrue);
      expect(provider.reactivateErrorMessage, isNull);
    });

    test('failed reactivateProcessStep captures error message and returns false', () async {
      when(() => mockService.reactivateProcessStep('s3'))
          .thenThrow(const ApiException(message: 'Active process step name already exists', statusCode: 409));

      final result = await provider.reactivateProcessStep('s3');

      verify(() => mockService.reactivateProcessStep('s3')).called(1);
      expect(result, isFalse);
      expect(provider.reactivateErrorMessage, 'Active process step name already exists');
    });

    test('duplicate simultaneous reactivateProcessStep request is prevented', () async {
      when(() => mockService.reactivateProcessStep('s3')).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return stepActive1;
      });
      when(() => mockService.fetchProcessSteps()).thenAnswer((_) async => [stepActive1]);

      final f1 = provider.reactivateProcessStep('s3');
      final f2 = provider.reactivateProcessStep('s3');

      final results = await Future.wait([f1, f2]);
      expect(results[0], isTrue);
      expect(results[1], isFalse);
      verify(() => mockService.reactivateProcessStep('s3')).called(1);
    });
  });
}
