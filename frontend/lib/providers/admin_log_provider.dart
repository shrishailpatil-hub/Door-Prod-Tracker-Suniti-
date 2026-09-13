import 'package:flutter/foundation.dart';
import '../core/errors/api_exception.dart';
import '../models/job_step_history.dart';
import '../services/admin_log_service.dart';

class AdminLogProvider extends ChangeNotifier {
  final AdminLogService _adminLogService;

  AdminLogProvider({AdminLogService? adminLogService})
      : _adminLogService = adminLogService ?? AdminLogService();

  List<JobStepHistory> _logs = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool _isExporting = false;
  String? _exportErrorMessage;

  List<JobStepHistory> get logs => List.unmodifiable(_logs);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isExporting => _isExporting;
  String? get exportErrorMessage => _exportErrorMessage;

  /// Fetches all system audit logs for admin.
  Future<void> fetchLogs() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _logs = await _adminLogService.getAdminLogs();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'An unexpected error occurred.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Exports all job logs as Excel and returns binary bytes.
  Future<Uint8List?> exportLogsExcel() async {
    if (_isExporting) {
      return null;
    }

    _isExporting = true;
    _exportErrorMessage = null;
    notifyListeners();

    try {
      final bytes = await _adminLogService.exportAdminLogsExcel();
      return bytes;
    } on ApiException catch (e) {
      _exportErrorMessage = e.message;
      return null;
    } catch (_) {
      _exportErrorMessage = 'Failed to export Excel file';
      return null;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }
}
