import 'package:flutter/foundation.dart';
import '../core/errors/api_exception.dart';
import '../models/admin/process_step.dart';
import '../services/admin_process_step_service.dart';

class AdminProcessStepProvider extends ChangeNotifier {
  final AdminProcessStepService _service;

  AdminProcessStepProvider({AdminProcessStepService? service})
      : _service = service ?? AdminProcessStepService();

  List<ProcessStep> _steps = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Create-specific state
  bool _isCreating = false;
  String? _createErrorMessage;

  // Update-specific state
  bool _isUpdating = false;
  String? _updateErrorMessage;

  // Deactivate-specific state
  bool _isDeactivating = false;
  String? _deactivateErrorMessage;

  // Reactivate-specific state
  bool _isReactivating = false;
  String? _reactivateErrorMessage;

  List<ProcessStep> get steps => List.unmodifiable(_steps);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isCreating => _isCreating;
  String? get createErrorMessage => _createErrorMessage;

  bool get isUpdating => _isUpdating;
  String? get updateErrorMessage => _updateErrorMessage;

  bool get isDeactivating => _isDeactivating;
  String? get deactivateErrorMessage => _deactivateErrorMessage;

  bool get isReactivating => _isReactivating;
  String? get reactivateErrorMessage => _reactivateErrorMessage;

  /// Derived list of active steps sorted by stepOrder ASC
  List<ProcessStep> get activeSteps {
    final active = _steps.where((s) => s.isActive).toList();
    active.sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
    return active;
  }

  /// Derived list of inactive steps sorted consistently with server order
  List<ProcessStep> get inactiveSteps {
    return _steps.where((s) => !s.isActive).toList();
  }

  /// Fetches all process steps from backend.
  Future<void> fetchProcessSteps() async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _steps = await _service.fetchProcessSteps();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'An unexpected error occurred.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new master process step and refreshes from backend.
  Future<bool> createProcessStep({
    required String name,
    required int stepOrder,
  }) async {
    if (_isCreating) return false;
    _isCreating = true;
    _createErrorMessage = null;
    notifyListeners();

    try {
      await _service.createProcessStep(
        name: name,
        stepOrder: stepOrder,
      );
      await fetchProcessSteps();
      return true;
    } on ApiException catch (e) {
      _createErrorMessage = e.message;
      return false;
    } catch (_) {
      _createErrorMessage = 'An unexpected error occurred.';
      return false;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  /// Updates an existing master process step and refreshes from backend.
  Future<bool> updateProcessStep({
    required String id,
    required String name,
    required int stepOrder,
  }) async {
    if (_isUpdating) return false;
    _isUpdating = true;
    _updateErrorMessage = null;
    notifyListeners();

    try {
      await _service.updateProcessStep(
        id: id,
        name: name,
        stepOrder: stepOrder,
      );
      await fetchProcessSteps();
      return true;
    } on ApiException catch (e) {
      _updateErrorMessage = e.message;
      return false;
    } catch (_) {
      _updateErrorMessage = 'An unexpected error occurred.';
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  /// Deactivates a master process step and refreshes from backend.
  Future<bool> deactivateProcessStep(String id) async {
    if (_isDeactivating) return false;
    _isDeactivating = true;
    _deactivateErrorMessage = null;
    notifyListeners();

    try {
      await _service.deactivateProcessStep(id);
      await fetchProcessSteps();
      return true;
    } on ApiException catch (e) {
      _deactivateErrorMessage = e.message;
      return false;
    } catch (_) {
      _deactivateErrorMessage = 'An unexpected error occurred.';
      return false;
    } finally {
      _isDeactivating = false;
      notifyListeners();
    }
  }

  /// Reactivates an inactive master process step and refreshes from backend.
  Future<bool> reactivateProcessStep(String id) async {
    if (_isReactivating) return false;
    _isReactivating = true;
    _reactivateErrorMessage = null;
    notifyListeners();

    try {
      await _service.reactivateProcessStep(id);
      await fetchProcessSteps();
      return true;
    } on ApiException catch (e) {
      _reactivateErrorMessage = e.message;
      return false;
    } catch (_) {
      _reactivateErrorMessage = 'An unexpected error occurred.';
      return false;
    } finally {
      _isReactivating = false;
      notifyListeners();
    }
  }
}
