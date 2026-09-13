import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:frontend/core/errors/api_exception.dart';
import 'package:frontend/models/job_step_history.dart';
import 'package:frontend/providers/admin_log_provider.dart';
import 'package:frontend/services/admin_log_service.dart';

class MockAdminLogService extends Mock implements AdminLogService {}

void main() {
  late MockAdminLogService mockService;
  late AdminLogProvider provider;

  setUp(() {
    mockService = MockAdminLogService();
    provider = AdminLogProvider(adminLogService: mockService);
  });

  group('AdminLogProvider.fetchLogs', () {
    test('successful fetch updates logs and clears loading and error', () async {
      final mockLogs = [
        JobStepHistory(
          id: 'log-1',
          jobId: 'job-1',
          stepName: 'Cutting',
          action: JobStepAction.completed,
          performedBy: 'Worker Bob',
          createdAt: DateTime.parse('2026-09-09T10:00:00Z'),
        ),
      ];

      when(() => mockService.getAdminLogs()).thenAnswer((_) async => mockLogs);

      final future = provider.fetchLogs();
      expect(provider.isLoading, isTrue);
      expect(provider.errorMessage, isNull);

      await future;

      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.logs.length, 1);
      expect(provider.logs.first.id, 'log-1');
      verify(() => mockService.getAdminLogs()).called(1);
    });

    test('empty logs list is handled properly', () async {
      when(() => mockService.getAdminLogs()).thenAnswer((_) async => []);

      await provider.fetchLogs();

      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.logs, isEmpty);
    });

    test('captures ApiException into errorMessage', () async {
      when(() => mockService.getAdminLogs())
          .thenThrow(const ApiException(message: 'Unauthorized'));

      await provider.fetchLogs();

      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, 'Unauthorized');
      expect(provider.logs, isEmpty);
    });

    test('captures generic exception into fallback error message', () async {
      when(() => mockService.getAdminLogs())
          .thenThrow(Exception('Network error'));

      await provider.fetchLogs();

      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, 'An unexpected error occurred.');
    });
  });

  group('AdminLogProvider.exportLogsExcel', () {
    test('successful export returns binary bytes and resets loading', () async {
      final expectedBytes = Uint8List.fromList([1, 2, 3, 4]);
      when(() => mockService.exportAdminLogsExcel())
          .thenAnswer((_) async => expectedBytes);

      final future = provider.exportLogsExcel();
      expect(provider.isExporting, isTrue);
      expect(provider.exportErrorMessage, isNull);

      final result = await future;

      expect(result, expectedBytes);
      expect(provider.isExporting, isFalse);
      expect(provider.exportErrorMessage, isNull);
      verify(() => mockService.exportAdminLogsExcel()).called(1);
    });

    test('prevents duplicate concurrent export requests', () async {
      when(() => mockService.exportAdminLogsExcel()).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return Uint8List(5);
      });

      final f1 = provider.exportLogsExcel();
      final f2 = provider.exportLogsExcel();

      final results = await Future.wait([f1, f2]);
      expect(results[0], isNotNull);
      expect(results[1], isNull);
      verify(() => mockService.exportAdminLogsExcel()).called(1);
    });

    test('captures ApiException on export failure', () async {
      when(() => mockService.exportAdminLogsExcel())
          .thenThrow(const ApiException(message: 'Export failed on server'));

      final result = await provider.exportLogsExcel();

      expect(result, isNull);
      expect(provider.isExporting, isFalse);
      expect(provider.exportErrorMessage, 'Export failed on server');
    });

    test('captures generic exception on export failure', () async {
      when(() => mockService.exportAdminLogsExcel())
          .thenThrow(Exception('Socket closed'));

      final result = await provider.exportLogsExcel();

      expect(result, isNull);
      expect(provider.isExporting, isFalse);
      expect(provider.exportErrorMessage, 'Failed to export Excel file');
    });
  });
}
