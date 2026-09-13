import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/config/app_router.dart';
import 'package:frontend/models/auth/user_role.dart';
import 'package:frontend/providers/admin_user_provider.dart';
import 'package:frontend/screens/admin/admin_create_user_screen.dart';

class MockAdminUserProvider extends Mock implements AdminUserProvider {}

void main() {
  setUpAll(() {
    registerFallbackValue(UserRole.worker);
  });

  late MockAdminUserProvider mockUserProvider;

  setUp(() {
    mockUserProvider = MockAdminUserProvider();
    when(() => mockUserProvider.isCreating).thenReturn(false);
    when(() => mockUserProvider.createErrorMessage).thenReturn(null);
    when(() => mockUserProvider.addListener(any())).thenReturn(null);
    when(() => mockUserProvider.removeListener(any())).thenReturn(null);
  });

  Widget buildScreen() {
    return ChangeNotifierProvider<AdminUserProvider>.value(
      value: mockUserProvider,
      child: const MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: AdminCreateUserScreen(),
      ),
    );
  }

  testWidgets('renders all fields, buttons and labels', (tester) async {
    await tester.pumpWidget(buildScreen());

    expect(find.text('Create User'), findsWidgets);
    expect(find.widgetWithText(TextFormField, 'Name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.text('Role'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Create User'), findsOneWidget);
  });

  testWidgets('password is obscured by default and toggles visibility', (tester) async {
    await tester.pumpWidget(buildScreen());

    final passwordFieldFinder = find.byType(EditableText).at(2);
    final editableText = tester.widget<EditableText>(passwordFieldFinder);
    expect(editableText.obscureText, isTrue);

    // Tap toggle visibility
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();

    final toggledField = tester.widget<EditableText>(find.byType(EditableText).at(2));
    expect(toggledField.obscureText, isFalse);

    // Tap hide password
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pumpAndSettle();

    final rehiddenField = tester.widget<EditableText>(find.byType(EditableText).at(2));
    expect(rehiddenField.obscureText, isTrue);
  });

  testWidgets('role dropdown contains ADMIN, MANAGER, and WORKER options', (tester) async {
    await tester.pumpWidget(buildScreen());

    // Tap the dropdown
    await tester.tap(find.byType(DropdownButtonFormField<UserRole>));
    await tester.pumpAndSettle();

    expect(find.text('Administrator').last, findsOneWidget);
    expect(find.text('Floor Manager').last, findsOneWidget);
    expect(find.text('Assembly Worker').last, findsOneWidget);
  });

  testWidgets('validates empty name, empty email, empty password, missing role', (tester) async {
    await tester.pumpWidget(buildScreen());

    // Submit empty form
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create User'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(find.text('Please select a role'), findsOneWidget);
  });

  testWidgets('validates invalid email format', (tester) async {
    await tester.pumpWidget(buildScreen());

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'not-an-email');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create User'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email'), findsOneWidget);
  });

  testWidgets('validates password shorter than 8 characters', (tester) async {
    await tester.pumpWidget(buildScreen());

    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'short');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create User'));
    await tester.pumpAndSettle();

    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
  });

  testWidgets('successful submission calls provider and pops screen', (tester) async {
    when(() => mockUserProvider.createUser(
          name: 'Alice Wonder',
          email: 'alice@doorcorp.com',
          password: 'password123',
          role: UserRole.admin,
        )).thenAnswer((_) async => true);

    await tester.pumpWidget(
      ChangeNotifierProvider<AdminUserProvider>.value(
        value: mockUserProvider,
        child: MaterialApp(
          routes: {
            '/': (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminCreateUserScreen()),
                    ),
                    child: const Text('Go to Create'),
                  ),
                ),
          },
        ),
      ),
    );

    // Navigate to create screen
    await tester.tap(find.text('Go to Create'));
    await tester.pumpAndSettle();

    // Fill form
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Alice Wonder');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'alice@doorcorp.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');

    // Select role
    await tester.tap(find.byType(DropdownButtonFormField<UserRole>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Administrator').last);
    await tester.pumpAndSettle();

    // Submit
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create User'));
    await tester.pumpAndSettle();

    verify(() => mockUserProvider.createUser(
          name: 'Alice Wonder',
          email: 'alice@doorcorp.com',
          password: 'password123',
          role: UserRole.admin,
        )).called(1);

    expect(find.text('User created successfully'), findsOneWidget);
    // Verified popped back to root
    expect(find.text('Go to Create'), findsOneWidget);
  });

  testWidgets('displays API error and remains on screen when creation fails', (tester) async {
    when(() => mockUserProvider.createErrorMessage).thenReturn('Email already exists');
    when(() => mockUserProvider.createUser(
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          role: any(named: 'role'),
        )).thenAnswer((_) async => false);

    await tester.pumpWidget(buildScreen());

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Duplicate User');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'dup@doorcorp.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');

    await tester.tap(find.byType(DropdownButtonFormField<UserRole>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assembly Worker').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create User'));
    await tester.pumpAndSettle();

    expect(find.text('Email already exists'), findsOneWidget);
    // Still on Create User screen
    expect(find.widgetWithText(TextFormField, 'Name'), findsOneWidget);
  });

  testWidgets('button is disabled and shows progress indicator when isCreating is true', (tester) async {
    when(() => mockUserProvider.isCreating).thenReturn(true);

    await tester.pumpWidget(buildScreen());

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
