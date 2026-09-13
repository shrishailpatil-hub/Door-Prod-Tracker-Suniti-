// test/services/job_service_logs_test.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/api_config.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/models/job_step_history.dart';
import 'package:frontend/services/job_service.dart';
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

  group('JobService Logs & Export Tests', () {
    test('Manager all logs endpoint is called correctly', () async {
      String? requestedPath;
      final sampleLogs = [
        {
          'id': 'log-1',
          'jobId': 'job-1',
          'jobStepId': 'step-1',
          'stepName': 'Cutting',
          'action': 'COMPLETED',
          'performedBy': 'Worker One',
          'createdAt': '2026-09-09T10:00:00.000Z',
        },
      ];

      final mockClient = MockClient((request) async {
        requestedPath = request.url.path;
        return http.Response(jsonEncode(sampleLogs), 200);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080/api',
        storageService: storageService,
        httpClient: mockClient,
      );
      final jobService = JobService(apiClient: apiClient);

      final logs = await jobService.getManagerLogs();

      expect(requestedPath, '/api${ApiConfig.managerLogsEndpoint}');
      expect(logs.length, 1);
      expect(logs.first.id, 'log-1');
      expect(logs.first.stepName, 'Cutting');
      expect(logs.first.action, JobStepAction.completed);
    });

    test('Manager job logs endpoint includes the job ID correctly', () async {
      String? requestedPath;
      final sampleLogs = [
        {
          'id': 'log-2',
          'jobId': 'target-job-123',
          'jobStepId': null,
          'stepName': null,
          'action': 'JOB_COMPLETED',
          'performedBy': 'Manager Alice',
          'createdAt': '2026-09-09T11:00:00.000Z',
        },
      ];

      final mockClient = MockClient((request) async {
        requestedPath = request.url.path;
        return http.Response(jsonEncode(sampleLogs), 200);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080/api',
        storageService: storageService,
        httpClient: mockClient,
      );
      final jobService = JobService(apiClient: apiClient);

      final logs = await jobService.getManagerJobLogs('target-job-123');

      expect(
        requestedPath,
        '/api${ApiConfig.managerJobsEndpoint}/target-job-123/logs',
      );
      expect(logs.length, 1);
      expect(logs.first.jobId, 'target-job-123');
      expect(logs.first.action, JobStepAction.jobCompleted);
    });

    test(
      'Excel endpoint returns raw bytes without attempting JSON parsing',
      () async {
        String? requestedPath;
        final fakeExcelBytes = Uint8List.fromList([
          0x50,
          0x4B,
          0x03,
          0x04,
          0x14,
          0x00,
        ]);

        final mockClient = MockClient((request) async {
          requestedPath = request.url.path;
          return http.Response.bytes(
            fakeExcelBytes,
            200,
            headers: {
              'content-type':
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            },
          );
        });

        final apiClient = ApiClient(
          baseUrl: 'http://localhost:8080/api',
          storageService: storageService,
          httpClient: mockClient,
        );
        final jobService = JobService(apiClient: apiClient);

        final bytes = await jobService.exportManagerLogsExcel();

        expect(requestedPath, '/api${ApiConfig.managerLogsExportEndpoint}');
        expect(bytes, equals(fakeExcelBytes));
        expect(bytes.length, 6);
      },
    );
  });
}
