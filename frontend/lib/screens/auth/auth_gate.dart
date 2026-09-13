import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_scaffold.dart';
import 'login_screen.dart';

/// Evaluates restored authentication state and directs users to their role home.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isInitialized) {
      return const AppScaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppTheme.space16),
              Text(
                'Loading Application...',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    return _RoleRouteRedirect(
      routeName: AppRouter.getHomeRouteForRole(auth.session!.role),
    );
  }
}

class _RoleRouteRedirect extends StatefulWidget {
  const _RoleRouteRedirect({required this.routeName});

  final String routeName;

  @override
  State<_RoleRouteRedirect> createState() => _RoleRouteRedirectState();
}

class _RoleRouteRedirectState extends State<_RoleRouteRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(widget.routeName, (route) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(body: Center(child: CircularProgressIndicator()));
  }
}
