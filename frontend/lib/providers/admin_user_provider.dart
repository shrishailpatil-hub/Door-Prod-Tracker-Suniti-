import 'package:flutter/foundation.dart';
import '../models/auth/app_user.dart';
import '../services/admin_user_service.dart';
import '../core/errors/api_exception.dart';
import '../models/auth/user_role.dart';
class AdminUserProvider extends ChangeNotifier {
  final AdminUserService _userService;

  AdminUserProvider({AdminUserService? userService})
      : _userService = userService ?? AdminUserService();

  List<AppUser> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Update-specific state
  bool _isUpdating = false;
  String? _updateErrorMessage;

  // Create-specific state
  bool _isCreating = false;
  String? _createErrorMessage;

  List<AppUser> get users => _users;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isUpdating => _isUpdating;
  String? get updateErrorMessage => _updateErrorMessage;
  bool get isCreating => _isCreating;
  String? get createErrorMessage => _createErrorMessage;

  /// Fetches all system users.
  Future<void> fetchUsers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _users = await _userService.getUsers();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes the user list.
  Future<void> refreshUsers() async => fetchUsers();

  /// Updates an existing user and refreshes the list.
  Future<void> updateUser({
    required String id,
    required String name,
    required String email,
    required UserRole role,
  }) async {
    _isUpdating = true;
    _updateErrorMessage = null;
    notifyListeners();
    try {
      await _userService.updateUser(id: id, name: name, email: email, role: role);
      await fetchUsers();
    } on ApiException catch (e) {
      _updateErrorMessage = e.message;
    } catch (_) {
      _updateErrorMessage = 'An unexpected error occurred.';
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  /// Updates user active status (activate/deactivate).
  Future<void> updateUserStatus({
    required String id,
    required bool isActive,
  }) async {
    if (_isUpdating) return; // Guard against duplicate calls
    _isUpdating = true;
    _updateErrorMessage = null;
    notifyListeners();
    try {
      await _userService.updateUserStatus(id: id, isActive: isActive);
      await fetchUsers();
    } on ApiException catch (e) {
      _updateErrorMessage = e.message;
    } catch (_) {
      _updateErrorMessage = 'An unexpected error occurred.';
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  /// Creates a new user and refreshes the list.
  Future<bool> createUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    if (_isCreating) return false; // Guard against duplicate calls
    _isCreating = true;
    _createErrorMessage = null;
    notifyListeners();
    try {
      await _userService.createUser(
        name: name,
        email: email,
        password: password,
        role: role,
      );
      await fetchUsers();
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
}
