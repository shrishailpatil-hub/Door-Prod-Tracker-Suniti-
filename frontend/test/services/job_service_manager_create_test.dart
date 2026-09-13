import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/api_config.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/services/job_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/fake_secure_storage.dart';

void main() {
  test('createManagerJob posts the backend CreateJobRequest shape', () async {
    final storageService = SecureStorageService(
      storage: FakeFlutterSecureStorage(),
    );
    final mockClient = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api${ApiConfig.managerJobsEndpoint}');
      expect(jsonDecode(request.body), {
        'jobNumber': 'JOB-900',
        'companyName': 'Acme Doors',
      });
      return http.Response(jsonEncode(_jobJson()), 200);
    });
    final service = JobService(
      apiClient: ApiClient(
        baseUrl: 'http://example.com/api',
        storageService: storageService,
        httpClient: mockClient,
      ),
    );

    final job = await service.createManagerJob(
      jobNumber: 'JOB-900',
      companyName: 'Acme Doors',
    );

    expect(job.id, 'job-900');
    expect(job.jobNumber, 'JOB-900');
  });
}

Map<String, dynamic> _jobJson() => {
  'id': 'job-900',
  'jobNumber': 'JOB-900',
  'companyName': 'Acme Doors',
  'status': 'IN_PROGRESS',
  'createdBy': 'Manager Meera',
  'createdAt': '2026-09-10T09:00:00.000Z',
  'updatedAt': '2026-09-10T09:00:00.000Z',
  'completedAt': null,
  'chalanNumber': null,
  'steps': [],
};
