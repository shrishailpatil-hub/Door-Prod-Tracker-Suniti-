class ApiConfig {
  ApiConfig._();

  /// Base URL of the backend API.
  /// Can be overridden via dart-define at compile/run time:
  /// flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8080/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
      defaultValue: 'http://13.126.144.211/api',
  );

  // Authentication
  static const String loginEndpoint = '/auth/login';

  // Admin
  static const String adminUsersEndpoint = '/admin/users';
  static const String adminProcessStepsEndpoint = '/admin/process-steps';
  static const String adminLogsEndpoint = '/admin/logs';
  static const String adminLogsExportEndpoint = '/admin/logs/export';

  // Manager
  static const String managerJobsEndpoint = '/manager/jobs';
  static const String managerLogsEndpoint = '/manager/jobs/logs';
  static const String managerLogsExportEndpoint = '/manager/logs/export';

  // Worker
  static const String workerJobsEndpoint = '/worker/jobs';
  static const String workerJobStepsEndpoint = '/worker/job-steps';

  // Notifications
  static const String notificationsEndpoint = '/notifications';
}
