import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'core/config/app_router.dart';
import 'core/network/api_client.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'providers/admin_process_step_provider.dart';
import 'providers/admin_user_provider.dart';
import 'providers/admin_log_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/job_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/auth/auth_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = SecureStorageService();
  final apiClient = ApiClient(storageService: storageService);
  final authProvider = AuthProvider(
    apiClient: apiClient,
    storageService: storageService,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<SecureStorageService>.value(value: storageService),
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider<JobProvider>(
          create: (_) => JobProvider(),
        ),
        ChangeNotifierProvider<AdminUserProvider>(
          create: (_) => AdminUserProvider(),
        ),
        ChangeNotifierProvider<AdminProcessStepProvider>(
          create: (_) => AdminProcessStepProvider(),
        ),
        ChangeNotifierProvider<AdminLogProvider>(
          create: (_) => AdminLogProvider(),
        ),
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) => NotificationProvider(),
        ),
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider..initialize(),
        ),
      ],
      child: const DoorProcessApp(),
    ),
  );
}

class DoorProcessApp extends StatelessWidget {
  const DoorProcessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Door Process Workflow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: const AuthGate(),
    );
  }
}
