import 'dart:typed_data';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/errors/api_exception.dart';
import '../models/job.dart';
import '../models/job_step_history.dart';

class JobService {
  final ApiClient _apiClient;

  JobService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Fetches all jobs for the manager view.
  Future<List<Job>> getManagerJobs() async {
    final response = await _apiClient.get(ApiConfig.managerJobsEndpoint);
    if (response is! List) {
      throw ApiException(
        message: 'Unexpected response format for manager jobs',
      );
    }
    return response
        .map((e) => Job.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Job> createManagerJob({
    required String jobNumber,
    required String companyName,
    String? fr,
    String? deliveryAddress,
    String? poNo,
    String? gstNo,
    DateTime? poDate,
    DateTime? orderDate,
    DateTime? deliveryDate,
    String? doors,
    String? doorLeaf,
    String? colourShade,
    String? vehicleDetails,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.managerJobsEndpoint,
      body: {
        'jobNumber': jobNumber,
        'companyName': companyName,
        if (fr != null) 'fr': fr,
        if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
        if (poNo != null) 'poNo': poNo,
        if (gstNo != null) 'gstNo': gstNo,
        if (poDate != null) 'poDate': poDate.toIso8601String().split('T').first,
        if (orderDate != null) 'orderDate': orderDate.toIso8601String().split('T').first,
        if (deliveryDate != null) 'deliveryDate': deliveryDate.toIso8601String().split('T').first,
        if (doors != null) 'doors': doors,
        if (doorLeaf != null) 'doorLeaf': doorLeaf,
        if (colourShade != null) 'colourShade': colourShade,
        if (vehicleDetails != null) 'vehicleDetails': vehicleDetails,
      },
    );
    if (response is! Map) {
      throw const ApiException(
        message: 'Unexpected response format for manager job creation',
      );
    }
    return Job.fromJson(response as Map<String, dynamic>);
  }

  /// Fetches active jobs for the authenticated worker.
  Future<List<Job>> getActiveJobs() async {
    final response = await _apiClient.get(ApiConfig.workerJobsEndpoint);
    if (response is! List) {
      throw ApiException(message: 'Unexpected response format for active jobs');
    }
    return response
        .map((e) => Job.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches a single job detail for the worker.
  Future<Job> getWorkerJob(String jobId) async {
    final endpoint = '${ApiConfig.workerJobsEndpoint}/$jobId';
    final response = await _apiClient.get(endpoint);
    if (response is! Map) {
      throw ApiException(message: 'Unexpected response format for job detail');
    }
    return Job.fromJson(response as Map<String, dynamic>);
  }

  /// Fetches a single job detail for the manager.
  Future<Job> getManagerJob(String jobId) async {
    final endpoint = '${ApiConfig.managerJobsEndpoint}/$jobId';
    final response = await _apiClient.get(endpoint);
    if (response is! Map) {
      throw ApiException(
        message: 'Unexpected response format for manager job detail',
      );
    }
    return Job.fromJson(response as Map<String, dynamic>);
  }

  /// Complete a job step.

  Future<void> completeJobStep(String stepId) async {
    final endpoint = '${ApiConfig.workerJobStepsEndpoint}/$stepId/complete';
    await _apiClient.put(endpoint);
  }

  /// Undo a completed job step.
  Future<void> undoJobStep(String stepId) async {
    final endpoint = '${ApiConfig.workerJobStepsEndpoint}/$stepId/undo';
    await _apiClient.put(endpoint);
  }

  /// Add chalan number to a job.
  Future<void> addChalan(String jobId, String chalanNumber) async {
    final endpoint = '${ApiConfig.workerJobsEndpoint}/$jobId/chalan';
    await _apiClient.put(endpoint, body: {'chalanNumber': chalanNumber});
  }

  /// Mark the job as completed.
  Future<void> completeJob(String jobId) async {
    final endpoint = '${ApiConfig.workerJobsEndpoint}/$jobId/complete';
    await _apiClient.put(endpoint);
  }

  /// Cancel a manager job.
  Future<Job> cancelManagerJob(String jobId) async {
    final endpoint = '${ApiConfig.managerJobsEndpoint}/$jobId/cancel';
    final response = await _apiClient.put(endpoint);
    if (response is! Map) {
      throw ApiException(
        message: 'Unexpected response format for manager cancel',
      );
    }
    return Job.fromJson(response as Map<String, dynamic>);
  }

  /// Reopen a manager job step.
  Future<Job> reopenManagerJob(String jobId, String stepId) async {
    final endpoint = '${ApiConfig.managerJobsEndpoint}/$jobId/reopen';
    final response = await _apiClient.put(endpoint, body: {'stepId': stepId});
    if (response is! Map) {
      throw ApiException(
        message: 'Unexpected response format for manager reopen',
      );
    }
    return Job.fromJson(response as Map<String, dynamic>);
  }

  /// Fetches all system audit logs for the manager view.
  Future<List<JobStepHistory>> getManagerLogs() async {
    final response = await _apiClient.get(ApiConfig.managerLogsEndpoint);
    if (response is! List) {
      throw ApiException(
        message: 'Unexpected response format for manager logs',
      );
    }
    return response
        .map((e) => JobStepHistory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches audit logs for a specific job.
  Future<List<JobStepHistory>> getManagerJobLogs(String jobId) async {
    final endpoint = '${ApiConfig.managerJobsEndpoint}/$jobId/logs';
    final response = await _apiClient.get(endpoint);
    if (response is! List) {
      throw ApiException(
        message: 'Unexpected response format for manager job logs',
      );
    }
    return response
        .map((e) => JobStepHistory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Exports all job logs as an Excel sheet (raw binary bytes).
  Future<Uint8List> exportManagerLogsExcel() async {
    return _apiClient.getBytes(ApiConfig.managerLogsExportEndpoint);
  }
}
