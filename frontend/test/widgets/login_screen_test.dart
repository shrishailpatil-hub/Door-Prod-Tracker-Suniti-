import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_router.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/auth/auth_gate.dart';
import 'package:frontend/screens/auth/login_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import '../helpers/fake_secure_storage.dart';

void main() {
  late FakeFlutterSecureStorage fakeStorage;
  late SecureStorageService storageService;

  setUp(() {
    fakeStorage = FakeFlutterSecureStorage();
    storageService = SecureStorageService(storage: fakeStorage);
  });

  AuthProvider buildAuthProvider(http.Client client) {
    return AuthProvider(
      apiClient: ApiClient(
        baseUrl: 'http://example.com/api',
        storageService: storageService,
        httpClient: client,
      ),
      storageService: storageService,
    );
  }

  Widget buildLogin(AuthProvider authProvider) {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: MaterialApp(theme: AppTheme.lightTheme, home: const LoginScreen()),
    );
  }

  testWidgets('renders the login form', (tester) async {
    final authProvider = buildAuthProvider(
      MockClient((_) async {
        throw UnimplementedError();
      }),
    );

    await tester.pumpWidget(buildLogin(authProvider));

    expect(find.text('Door Process Workflow'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('validates missing and invalid email values', (tester) async {
    final authProvider = buildAuthProvider(
      MockClient((_) async {
        throw UnimplementedError();
      }),
    );
    await tester.pumpWidget(buildLogin(authProvider));

    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Email is required.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('validates a missing password', (tester) async {
    final authProvider = buildAuthProvider(
      MockClient((_) async {
        throw UnimplementedError();
      }),
    );
    await tester.pumpWidget(buildLogin(authProvider));

    await tester.enterText(
      find.byType(TextFormField).first,
      'manager@example.com',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('submits credentials through AuthProvider', (tester) async {
    var calls = 0;
    final authProvider = buildAuthProvider(
      MockClient((request) async {
        calls++;
        expect(jsonDecode(request.body), {
          'email': 'manager@example.com',
          'password': 'password123',
        });
        return http.Response(
          jsonEncode({
            'token': 'token',
            'userId': 'manager-1',
            'name': 'Manager Meera',
            'role': 'MANAGER',
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(buildLogin(authProvider));

    await tester.enterText(
      find.byType(TextFormField).first,
      'manager@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(authProvider.isAuthenticated, isTrue);
  });

  testWidgets('prevents duplicate submissions while logging in', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    var calls = 0;
    final authProvider = buildAuthProvider(
      MockClient((_) {
        calls++;
        return response.future;
      }),
    );
    await tester.pumpWidget(buildLogin(authProvider));

    await tester.enterText(
      find.byType(TextFormField).first,
      'manager@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    response.complete(http.Response('{"message":"Invalid credentials"}', 401));
    await tester.pumpAndSettle();
  });

  testWidgets('shows a friendly invalid-credentials error', (tester) async {
    final authProvider = buildAuthProvider(
      MockClient((_) async {
        return http.Response('{"message":"Invalid credentials"}', 401);
      }),
    );
    await tester.pumpWidget(buildLogin(authProvider));

    await tester.enterText(
      find.byType(TextFormField).first,
      'manager@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'wrong-password');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Email or password is incorrect.'), findsOneWidget);
  });

  testWidgets('shows a friendly network error', (tester) async {
    final authProvider = buildAuthProvider(
      MockClient((_) async {
        throw http.ClientException('offline');
      }),
    );
    await tester.pumpWidget(buildLogin(authProvider));

    await tester.enterText(
      find.byType(TextFormField).first,
      'manager@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unable to reach the server. Check your connection and try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('toggles password visibility', (tester) async {
    final authProvider = buildAuthProvider(
      MockClient((_) async {
        throw UnimplementedError();
      }),
    );
    await tester.pumpWidget(buildLogin(authProvider));

    expect(find.byTooltip('Show password'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('successful login is routed by AuthGate to the role home', (
    tester,
  ) async {
    final authProvider = buildAuthProvider(
      MockClient((_) async {
        return http.Response(
          jsonEncode({
            'token': 'token',
            'userId': 'admin-1',
            'name': 'Admin Priya',
            'role': 'ADMIN',
          }),
          200,
        );
      }),
    );
    await authProvider.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const AuthGate(),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'admin@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Admin Priya'), findsOneWidget);
  });

  testWidgets('restored session is routed by AuthGate without showing login', (
    tester,
  ) async {
    await storageService.saveSession(
      token: 'stored-token',
      userId: 'admin-1',
      name: 'Admin Priya',
      role: 'ADMIN',
    );
    final authProvider = buildAuthProvider(
      MockClient((_) async {
        throw UnimplementedError();
      }),
    );
    await authProvider.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const AuthGate(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Admin Priya'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });
}
