// lib/core/config/app_router.dart

import 'package:flutter/material.dart';

import '../../models/auth/user_role.dart';
import '../../screens/auth/auth_gate.dart';
import '../../screens/worker/worker_home_screen.dart';
import '../../screens/worker/worker_job_detail_screen.dart';
import '../../screens/manager/manager_home_screen.dart';
import '../../screens/manager/manager_create_job_screen.dart';
import '../../screens/manager/manager_job_detail_screen.dart';
import '../../screens/manager/manager_logs_screen.dart';
import '../../screens/manager/manager_job_logs_screen.dart';
import '../../screens/manager/manager_notifications_screen.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/admin/admin_user_list_screen.dart';
import '../../screens/admin/admin_edit_user_screen.dart';
import '../../screens/admin/admin_create_user_screen.dart';
import '../../screens/admin/admin_process_step_list_screen.dart';
import '../../screens/admin/admin_logs_screen.dart';

/// Centralized route constants and routing helper for application navigation.
class AppRouter {
  AppRouter._();

  // Route constants
  static const String splash = '/';
  static const String login = '/login';
  static const String workerHome = '/worker';
  static const String managerHome = '/manager';
  static const String managerCreateJob = '/manager/jobs/create';
  static const String managerLogs = '/manager/logs';
  static const String managerNotifications = '/manager/notifications';
  static const String adminHome = '/admin';
  static const String adminUsers = '/admin/users';
  static const String adminCreateUser = '/admin/users/create';
  static const String adminProcessSteps = '/admin/process-steps';
  static const String adminLogs = '/admin/logs';
  static const String adminEditUser = '/admin/users/edit';

  /// Resolves the home route for a given user role.
  static String getHomeRouteForRole(UserRole role) {
    switch (role) {
      case UserRole.worker:
        return workerHome;
      case UserRole.manager:
        return managerHome;
      case UserRole.admin:
        return adminHome;
    }
  }

  /// Generates routes.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      case login:
        return MaterialPageRoute(builder: (_) => const AuthGate());
      case workerHome:
        return MaterialPageRoute(builder: (_) => const WorkerHomeScreen());
      case managerHome:
        return MaterialPageRoute(builder: (_) => const ManagerHomeScreen());
      case managerCreateJob:
        return MaterialPageRoute(builder: (_) => const ManagerCreateJobScreen());
      case managerLogs:
        return MaterialPageRoute(builder: (_) => const ManagerLogsScreen());
      case managerNotifications:
        return MaterialPageRoute(builder: (_) => const ManagerNotificationsScreen());
      case adminHome:
        return MaterialPageRoute(builder: (_) => const AdminDashboardScreen());
      case adminUsers:
        return MaterialPageRoute(builder: (_) => const AdminUserListScreen());
      case adminCreateUser:
        return MaterialPageRoute(builder: (_) => const AdminCreateUserScreen());
      case adminEditUser:
        return MaterialPageRoute(
          builder: (_) => const AdminEditUserScreen(),
          settings: settings,
        );
      case adminProcessSteps:
        return MaterialPageRoute(
          builder: (_) => const AdminProcessStepListScreen(),
        );
      case adminLogs:
        return MaterialPageRoute(
          builder: (_) => const AdminLogsScreen(),
        );
      default:
        // Dynamic route for worker job detail, e.g. /worker/jobs/<jobId>
        if (settings.name != null && settings.name!.startsWith('/worker/jobs/')) {
          final jobId = settings.name!.split('/').last;
          return MaterialPageRoute(builder: (_) => WorkerJobDetailScreen(jobId: jobId));
        }
        // Manager job logs route e.g. /manager/jobs/<jobId>/logs
        if (settings.name != null && settings.name!.startsWith('/manager/jobs/') && settings.name!.endsWith('/logs')) {
          final segments = settings.name!.split('/');
          if (segments.length >= 5) {
            final jobId = segments[3];
            return MaterialPageRoute(builder: (_) => ManagerJobLogsScreen(jobId: jobId));
          }
        }
        // Manager job detail route
        if (settings.name != null && settings.name!.startsWith('/manager/jobs/')) {
          final jobId = settings.name!.split('/').last;
          return MaterialPageRoute(builder: (_) => ManagerJobDetailScreen(jobId: jobId));
        }
        return MaterialPageRoute(
          builder: (_) => Scaffold(body: Center(child: Text('Route not found: ${settings.name}'))),
        );
    }
  }
}
