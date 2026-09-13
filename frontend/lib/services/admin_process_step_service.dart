import '../core/config/api_config.dart';
import '../core/errors/api_exception.dart';
import '../core/network/api_client.dart';
import '../models/admin/process_step.dart';

class AdminProcessStepService {
  final ApiClient _apiClient;

  AdminProcessStepService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Fetches all master process steps (both active and inactive) from backend.
  Future<List<ProcessStep>> fetchProcessSteps() async {
    final response = await _apiClient.get(ApiConfig.adminProcessStepsEndpoint);
    if (response is! List) {
      throw const ApiException(
        message: 'Unexpected response format for process steps',
      );
    }
    return response
        .map((e) => ProcessStep.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Creates a new active master process step.
  Future<ProcessStep> createProcessStep({
    required String name,
    required int stepOrder,
  }) async {
    final body = {
      'name': name,
      'stepOrder': stepOrder,
    };
    final response = await _apiClient.post(
      ApiConfig.adminProcessStepsEndpoint,
      body: body,
    );
    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'Unexpected response format for created process step',
      );
    }
    return ProcessStep.fromJson(response);
  }

  /// Updates an existing master process step's name and/or order.
  Future<ProcessStep> updateProcessStep({
    required String id,
    required String name,
    required int stepOrder,
  }) async {
    final body = {
      'name': name,
      'stepOrder': stepOrder,
    };
    final response = await _apiClient.put(
      '${ApiConfig.adminProcessStepsEndpoint}/$id',
      body: body,
    );
    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'Unexpected response format for updated process step',
      );
    }
    return ProcessStep.fromJson(response);
  }

  /// Soft-deactivates an existing master process step.
  Future<ProcessStep> deactivateProcessStep(String id) async {
    final response = await _apiClient.delete(
      '${ApiConfig.adminProcessStepsEndpoint}/$id',
    );
    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'Unexpected response format for deactivated process step',
      );
    }
    return ProcessStep.fromJson(response);
  }

  /// Reactivates an inactive master process step.
  Future<ProcessStep> reactivateProcessStep(String id) async {
    final response = await _apiClient.post(
      '${ApiConfig.adminProcessStepsEndpoint}/$id/reactivate',
    );
    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'Unexpected response format for reactivated process step',
      );
    }
    return ProcessStep.fromJson(response);
  }
}
