import 'dart:typed_data';

import '../core/config/api_config.dart';
import '../core/errors/api_exception.dart';
import '../core/network/api_client.dart';
import '../models/job_step_history.dart';

class AdminLogService {
  final ApiClient _apiClient;

  AdminLogService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Fetches all system audit logs for the admin view.
  Future<List<JobStepHistory>> getAdminLogs() async {
    final response = await _apiClient.get(ApiConfig.adminLogsEndpoint);
    if (response is! List) {
      throw const ApiException(
        message: 'Unexpected response format for admin logs',
      );
    }
    return response
        .map((e) => JobStepHistory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Exports all job logs as an Excel sheet (raw binary bytes) for admin.
  Future<Uint8List> exportAdminLogsExcel() async {
    return _apiClient.getBytes(ApiConfig.adminLogsExportEndpoint);
  }
}
