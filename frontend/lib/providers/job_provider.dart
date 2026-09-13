import 'package:flutter/foundation.dart';
import '../models/job.dart';
import '../models/job_step_history.dart';
import '../services/job_service.dart';

class JobProvider extends ChangeNotifier {
  final JobService _jobService;

  JobProvider({JobService? jobService})
    : _jobService = jobService ?? JobService();

  // ---------- Active Jobs ----------
  List<Job> _jobs = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Job> get jobs => _jobs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ---------- Manager Jobs ----------
  List<Job> _managerJobs = [];
  bool _isManagerLoading = false;
  String? _managerErrorMessage;

  List<Job> get managerJobs => _managerJobs;
  bool get isManagerLoading => _isManagerLoading;
  String? get managerErrorMessage => _managerErrorMessage;

  Future<void> fetchActiveJobs() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _jobs = await _jobService.getActiveJobs();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshJobs() async {
    await fetchActiveJobs();
  }

  // ---------- Manager Jobs ----------
  Future<void> fetchManagerJobs() async {
    _isManagerLoading = true;
    _managerErrorMessage = null;
    notifyListeners();
    try {
      _managerJobs = await _jobService.getManagerJobs();
    } catch (e) {
      _managerErrorMessage = e.toString();
    } finally {
      _isManagerLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshManagerJobs() async => fetchManagerJobs();

  // ---------- Manager Job Creation ----------
  bool _isCreatingManagerJob = false;
  String? _managerCreateErrorMessage;

  bool get isCreatingManagerJob => _isCreatingManagerJob;
  String? get managerCreateErrorMessage => _managerCreateErrorMessage;

  /// Creates a manager job and refreshes the backend-backed manager job list.
  Future<Job?> createManagerJob({
    required String jobNumber,
    required String companyName,
  }) async {
    if (_isCreatingManagerJob) {
      return null;
    }

    _isCreatingManagerJob = true;
    _managerCreateErrorMessage = null;
    notifyListeners();
    try {
      final createdJob = await _jobService.createManagerJob(
        jobNumber: jobNumber,
        companyName: companyName,
      );
      await fetchManagerJobs();
      return createdJob;
    } catch (e) {
      _managerCreateErrorMessage = e.toString();
      return null;
    } finally {
      _isCreatingManagerJob = false;
      notifyListeners();
    }
  }

  // ---------- Manager Job Detail ----------
  Job? _managerSelectedJob;
  bool _isManagerDetailLoading = false;
  String? _managerDetailErrorMessage;

  Job? get managerSelectedJob => _managerSelectedJob;
  bool get isManagerDetailLoading => _isManagerDetailLoading;
  String? get managerDetailErrorMessage => _managerDetailErrorMessage;

  Future<void> fetchManagerJob(String jobId) async {
    _isManagerDetailLoading = true;
    _managerDetailErrorMessage = null;
    notifyListeners();
    try {
      _managerSelectedJob = await _jobService.getManagerJob(jobId);
    } catch (e) {
      _managerDetailErrorMessage = e.toString();
    } finally {
      _isManagerDetailLoading = false;
      notifyListeners();
    }
  }

  // ---------- Manager Cancel ----------
  String? _managerCancelLoadingJobId;
  String? _managerCancelErrorMessage;

  // ---------- Manager Reopen ----------
  String? _managerReopenLoadingJobId;
  String? _managerReopenErrorMessage;

  String? get managerCancelLoadingJobId => _managerCancelLoadingJobId;
  String? get managerCancelErrorMessage => _managerCancelErrorMessage;
  String? get managerReopenLoadingJobId => _managerReopenLoadingJobId;
  String? get managerReopenErrorMessage => _managerReopenErrorMessage;

  /// Cancel a manager job.
  Future<void> cancelManagerJob(String jobId) async {
    if (_managerCancelLoadingJobId == jobId ||
        _managerReopenLoadingJobId == jobId) {
      return;
    }
    _managerCancelLoadingJobId = jobId;
    _managerCancelErrorMessage = null;
    notifyListeners();
    try {
      final updatedJob = await _jobService.cancelManagerJob(jobId);
      // Update selected manager job if it matches
      if (_managerSelectedJob != null && _managerSelectedJob!.id == jobId) {
        _managerSelectedJob = updatedJob;
      }
    } catch (e) {
      _managerCancelErrorMessage = e.toString();
    } finally {
      _managerCancelLoadingJobId = null;
      notifyListeners();
    }
  }

  /// Reopen a manager job step.
  Future<void> reopenManagerJob(String jobId, String stepId) async {
    if (_managerReopenLoadingJobId == jobId ||
        _managerCancelLoadingJobId == jobId) {
      return;
    }
    _managerReopenLoadingJobId = jobId;
    _managerReopenErrorMessage = null;
    notifyListeners();
    try {
      final updatedJob = await _jobService.reopenManagerJob(jobId, stepId);
      if (_managerSelectedJob != null && _managerSelectedJob!.id == jobId) {
        _managerSelectedJob = updatedJob;
      }
    } catch (e) {
      _managerReopenErrorMessage = e.toString();
    } finally {
      _managerReopenLoadingJobId = null;
      notifyListeners();
    }
  }

  // ---------- Manager Logs State ----------
  List<JobStepHistory> _managerAllLogs = [];
  bool _isManagerLogsLoading = false;
  String? _managerLogsErrorMessage;

  List<JobStepHistory> _managerJobLogs = [];
  bool _isManagerJobLogsLoading = false;
  String? _managerJobLogsErrorMessage;

  bool _isExportingExcel = false;
  String? _exportErrorMessage;

  List<JobStepHistory> get managerAllLogs => _managerAllLogs;
  bool get isManagerLogsLoading => _isManagerLogsLoading;
  String? get managerLogsErrorMessage => _managerLogsErrorMessage;

  List<JobStepHistory> get managerJobLogs => _managerJobLogs;
  bool get isManagerJobLogsLoading => _isManagerJobLogsLoading;
  String? get managerJobLogsErrorMessage => _managerJobLogsErrorMessage;

  bool get isExportingExcel => _isExportingExcel;
  String? get exportErrorMessage => _exportErrorMessage;

  /// Fetches all system audit logs for the manager.
  Future<void> fetchManagerLogs() async {
    _isManagerLogsLoading = true;
    _managerLogsErrorMessage = null;
    notifyListeners();
    try {
      _managerAllLogs = await _jobService.getManagerLogs();
    } catch (e) {
      _managerLogsErrorMessage = e.toString();
    } finally {
      _isManagerLogsLoading = false;
      notifyListeners();
    }
  }

  /// Fetches audit logs for a specific job.
  Future<void> fetchManagerJobLogs(String jobId) async {
    _isManagerJobLogsLoading = true;
    _managerJobLogsErrorMessage = null;
    notifyListeners();
    try {
      _managerJobLogs = await _jobService.getManagerJobLogs(jobId);
    } catch (e) {
      _managerJobLogsErrorMessage = e.toString();
    } finally {
      _isManagerJobLogsLoading = false;
      notifyListeners();
    }
  }

  /// Exports all job logs as Excel and returns binary bytes.
  Future<Uint8List?> exportManagerLogsExcel() async {
    if (_isExportingExcel) {
      return null;
    }

    _isExportingExcel = true;
    _exportErrorMessage = null;
    notifyListeners();
    try {
      final bytes = await _jobService.exportManagerLogsExcel();
      return bytes;
    } catch (e) {
      _exportErrorMessage = e.toString();
      return null;
    } finally {
      _isExportingExcel = false;
      notifyListeners();
    }
  }

  Job? _selectedJob;
  bool _isDetailLoading = false;
  String? _detailErrorMessage;

  Job? get selectedJob => _selectedJob;
  bool get isDetailLoading => _isDetailLoading;
  String? get detailErrorMessage => _detailErrorMessage;

  Future<void> fetchJobDetail(String jobId) async {
    _isDetailLoading = true;
    _detailErrorMessage = null;
    notifyListeners();
    try {
      _selectedJob = await _jobService.getWorkerJob(jobId);
    } catch (e) {
      _detailErrorMessage = e.toString();
    } finally {
      _isDetailLoading = false;
      notifyListeners();
    }
  }

  void clearSelectedJob() {
    _selectedJob = null;
    _detailErrorMessage = null;
    // Loading flag is managed by fetch calls.
    notifyListeners();
  }

  // ---------- Step Actions ----------
  String? _actionLoadingStepId;
  String? _stepActionError;

  // ---------- Job Actions ----------
  String? _actionLoadingJobId;
  String? _actionError;

  String? get actionLoadingStepId => _actionLoadingStepId;
  String? get stepActionError => _stepActionError;
  String? get actionLoadingJobId => _actionLoadingJobId;
  String? get actionError => _actionError;

  Future<void> completeStep(String stepId) async {
    _actionLoadingStepId = stepId;
    _stepActionError = null;
    notifyListeners();
    try {
      await _jobService.completeJobStep(stepId);
      // Refresh job detail after mutation
      if (_selectedJob != null) {
        await fetchJobDetail(_selectedJob!.id);
      }
    } catch (e) {
      _stepActionError = e.toString();
    } finally {
      _actionLoadingStepId = null;
      notifyListeners();
    }
  }

  Future<void> undoStep(String stepId) async {
    _actionLoadingStepId = stepId;
    _stepActionError = null;
    notifyListeners();
    try {
      await _jobService.undoJobStep(stepId);
      if (_selectedJob != null) {
        await fetchJobDetail(_selectedJob!.id);
      }
    } catch (e) {
      _stepActionError = e.toString();
    } finally {
      _actionLoadingStepId = null;
      notifyListeners();
    }
  }

  /// Clears the step action error.
  void clearStepActionError() {
    _stepActionError = null;
    notifyListeners();
  }

  /// Clears the job‑level action error.
  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }

  /// Adds a chalan number to the job.
  Future<void> addChalan(String jobId, String chalanNumber) async {
    _actionLoadingJobId = jobId;
    _actionError = null;
    notifyListeners();
    try {
      await _jobService.addChalan(jobId, chalanNumber);
      // Refresh job detail after mutation
      if (_selectedJob != null) {
        await fetchJobDetail(_selectedJob!.id);
      }
    } catch (e) {
      _actionError = e.toString();
    } finally {
      _actionLoadingJobId = null;
      notifyListeners();
    }
  }

  /// Marks the job as completed.
  Future<void> completeJob(String jobId) async {
    _actionLoadingJobId = jobId;
    _actionError = null;
    notifyListeners();
    try {
      await _jobService.completeJob(jobId);
      if (_selectedJob != null) {
        await fetchJobDetail(_selectedJob!.id);
      }
    } catch (e) {
      _actionError = e.toString();
    } finally {
      _actionLoadingJobId = null;
      notifyListeners();
    }
  }
}
