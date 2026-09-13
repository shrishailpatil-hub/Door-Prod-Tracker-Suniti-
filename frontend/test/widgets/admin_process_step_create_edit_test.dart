// Flutter widget tests for admin process step create/edit dialogs
// Uses a fake provider to avoid mockito dependency.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frontend/models/admin/process_step.dart';
import 'package:frontend/providers/admin_process_step_provider.dart';
import 'package:frontend/screens/admin/admin_process_step_list_screen.dart';

class FakeAdminProcessStepProvider extends ChangeNotifier implements AdminProcessStepProvider {
  // Provider state fields
  bool _isLoading = false;
  String? _errorMessage;
  List<ProcessStep> activeSteps = [];
  List<ProcessStep> inactiveSteps = [];
  bool _isCreating = false;
  bool _isUpdating = false;
  bool _isDeactivating = false;
  String? _createErrorMessage;
  String? _updateErrorMessage;
  String? _deactivateErrorMessage;

  bool _createSuccess = true;
  bool _updateSuccess = true;

  void setCreateResult(bool success, {String? errorMessage}) {
    _createSuccess = success;
    _createErrorMessage = errorMessage;
  }

  void setUpdateResult(bool success, {String? errorMessage}) {
    _updateSuccess = success;
    _updateErrorMessage = errorMessage;
  }

  // Interface getters
  @override
  bool get isLoading => _isLoading;

  @override
  String? get errorMessage => _errorMessage;

  @override
  bool get isCreating => _isCreating;

  @override
  String? get createErrorMessage => _createErrorMessage;

  @override
  bool get isUpdating => _isUpdating;

  @override
  String? get updateErrorMessage => _updateErrorMessage;

  @override
  bool get isDeactivating => _isDeactivating;

  @override
  String? get deactivateErrorMessage => _deactivateErrorMessage;

  @override
  bool get isReactivating => false;

  @override
  String? get reactivateErrorMessage => null;

  @override
  List<ProcessStep> get steps => [...activeSteps, ...inactiveSteps];

  @override
  Future<bool> createProcessStep({required String name, required int stepOrder}) async {
    _isCreating = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 1));
    _isCreating = false;
    if (_createSuccess) _createErrorMessage = null;
    else _createErrorMessage ??= 'Create failed';
    notifyListeners();
    return _createSuccess;
  }

  @override
  Future<bool> updateProcessStep({required String id, required String name, required int stepOrder}) async {
    _isUpdating = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 1));
    _isUpdating = false;
    if (_updateSuccess) _updateErrorMessage = null;
    else _updateErrorMessage ??= 'Update failed';
    notifyListeners();
    return _updateSuccess;
  }

  @override
  Future<void> fetchProcessSteps() async {}

  @override
  Future<bool> deactivateProcessStep(String id) async {
    _isDeactivating = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 1));
    _isDeactivating = false;
    // Deactivate not used in this phase; return true for completeness.
    notifyListeners();
    return true;
  }

  @override
  Future<bool> reactivateProcessStep(String id) async {
    return true;
  }

  // Dummy constructor to satisfy the abstract class signature.
  FakeAdminProcessStepProvider({required String dummy});
}

void main() {
  late FakeAdminProcessStepProvider fakeProvider;

  setUp(() {
    fakeProvider = FakeAdminProcessStepProvider(dummy: '');
    // Reset provider state.
    fakeProvider._isLoading = false;
    fakeProvider._errorMessage = null;
    fakeProvider.activeSteps = [];
    fakeProvider.inactiveSteps = [];
    fakeProvider._isCreating = false;
    fakeProvider._isUpdating = false;
    fakeProvider._isDeactivating = false;
    fakeProvider._createErrorMessage = null;
    fakeProvider._updateErrorMessage = null;
    fakeProvider._deactivateErrorMessage = null;
    fakeProvider.setCreateResult(true);
    fakeProvider.setUpdateResult(true);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AdminProcessStepProvider>.value(
          value: fakeProvider,
          child: const AdminProcessStepListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Create dialog opens when Add button tapped', (tester) async {
    await pumpScreen(tester);
    expect(find.byTooltip('Add Process Step'), findsOneWidget);
    await tester.tap(find.byTooltip('Add Process Step'));
    await tester.pumpAndSettle();
    expect(find.text('Create Process Step'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Step Name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Step Order'), findsOneWidget);
  });

  testWidgets('Create validation: blank name rejected', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('Add Process Step'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Step Name'), '');
    await tester.enterText(find.widgetWithText(TextFormField, 'Step Order'), '1');
    await tester.tap(find.text('Create'));
    await tester.pump();
    expect(find.text('Name required'), findsOneWidget);
  });

  testWidgets('Create validation: non-numeric order rejected', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('Add Process Step'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Step Name'), 'Step A');
    await tester.enterText(find.widgetWithText(TextFormField, 'Step Order'), 'abc');
    await tester.tap(find.text('Create'));
    await tester.pump();
    expect(find.textContaining('Order must be between'), findsOneWidget);
  });

  testWidgets('Create validation: out-of-range order rejected', (tester) async {
    fakeProvider.activeSteps = [
      ProcessStep(id: '1', name: 'One', stepOrder: 1, isActive: true, createdAt: DateTime.now(), updatedAt: DateTime.now()),
      ProcessStep(id: '2', name: 'Two', stepOrder: 2, isActive: true, createdAt: DateTime.now(), updatedAt: DateTime.now()),
    ];
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('Add Process Step'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Step Name'), 'Step X');
    await tester.enterText(find.widgetWithText(TextFormField, 'Step Order'), '5');
    await tester.tap(find.text('Create'));
    await tester.pump();
    expect(find.textContaining('Order must be between 1 and 3'), findsOneWidget);
  });

  testWidgets('Create loading state disables button and shows progress', (tester) async {
    fakeProvider._isCreating = true;
    await pumpScreen(tester);
    // Open the create dialog
    await tester.tap(find.byTooltip('Add Process Step'));
    await tester.pump();
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Create server error keeps dialog open and displays message', (tester) async {
    fakeProvider.setCreateResult(false, errorMessage: 'Duplicate name');
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('Add Process Step'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Step Name'), 'Existing');
    await tester.enterText(find.widgetWithText(TextFormField, 'Step Order'), '1');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Duplicate name'), findsOneWidget);
    expect(find.text('Create Process Step'), findsOneWidget);
  });

  testWidgets('Successful create closes dialog', (tester) async {
    fakeProvider.setCreateResult(true);
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('Add Process Step'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Step Name'), 'New Step');
    await tester.enterText(find.widgetWithText(TextFormField, 'Step Order'), '1');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Create Process Step'), findsNothing);
  });

  testWidgets('Edit dialog opens with prepopulated values', (tester) async {
    final step = ProcessStep(id: '10', name: 'Old Name', stepOrder: 2, isActive: true, createdAt: DateTime.now(), updatedAt: DateTime.now());
    fakeProvider.activeSteps = [step];
    await pumpScreen(tester);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.edit));
    await tester.pump(); // No settle needed
    expect(find.text('Edit Process Step'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Step Name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Step Order'), findsOneWidget);
    // Verify prepopulated values inside the TextFormFields
    expect(find.widgetWithText(TextFormField, 'Old Name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '2'), findsOneWidget);
  });

  testWidgets('Edit validation mirrors create rules', (tester) async {
    final step = ProcessStep(id: '10', name: 'Old', stepOrder: 2, isActive: true, createdAt: DateTime.now(), updatedAt: DateTime.now());
    fakeProvider.activeSteps = [step];
    await pumpScreen(tester);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.edit));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Step Name'), '');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Name required'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Step Name'), 'New');
    await tester.enterText(find.widgetWithText(TextFormField, 'Step Order'), 'abc');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.textContaining('Order must be between'), findsOneWidget);
  });

  testWidgets('Edit loading state disables save button', (tester) async {
    final step = ProcessStep(id: '10', name: 'Old', stepOrder: 2, isActive: true, createdAt: DateTime.now(), updatedAt: DateTime.now());
    fakeProvider.activeSteps = [step];
    fakeProvider._isUpdating = true;
    await pumpScreen(tester);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.edit));
    await tester.pump(); // No settle needed
    // Locate the disabled Save button (onPressed == null)
    final buttonFinder = find.byWidgetPredicate((widget) =>
        widget is ElevatedButton && widget.onPressed == null);
    final button = tester.widget<ElevatedButton>(buttonFinder);
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Edit server error stays open and shows message', (tester) async {
    final step = ProcessStep(id: '10', name: 'Old', stepOrder: 2, isActive: true, createdAt: DateTime.now(), updatedAt: DateTime.now());
    fakeProvider.activeSteps = [step];
    fakeProvider.setUpdateResult(false, errorMessage: 'Validation error');
    await pumpScreen(tester);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.edit));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Step Name'), 'New');
    await tester.enterText(find.widgetWithText(TextFormField, 'Step Order'), '1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Validation error'), findsOneWidget);
    expect(find.text('Edit Process Step'), findsOneWidget);
  });

  testWidgets('Successful edit closes dialog', (tester) async {
    final step = ProcessStep(id: '10', name: 'Old', stepOrder: 2, isActive: true, createdAt: DateTime.now(), updatedAt: DateTime.now());
    fakeProvider.activeSteps = [step];
    fakeProvider.setUpdateResult(true);
    await pumpScreen(tester);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.edit));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Step Name'), 'New');
    await tester.enterText(find.widgetWithText(TextFormField, 'Step Order'), '1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Process Step'), findsNothing);
  });

  testWidgets('Inactive steps do not show Edit action', (tester) async {
    final step = ProcessStep(id: '20', name: 'Inactive', stepOrder: 3, isActive: false, createdAt: DateTime.now(), updatedAt: DateTime.now());
    fakeProvider.activeSteps = [];
    fakeProvider.inactiveSteps = [step];
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    expect(find.widgetWithIcon(IconButton, Icons.edit), findsNothing);
  });
}
