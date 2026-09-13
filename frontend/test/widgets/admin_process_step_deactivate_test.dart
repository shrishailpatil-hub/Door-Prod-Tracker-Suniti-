// Flutter widget tests for admin process step deactivation dialog

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frontend/models/admin/process_step.dart';
import 'package:frontend/providers/admin_process_step_provider.dart';
import 'package:frontend/screens/admin/admin_process_step_list_screen.dart';

class FakeAdminProcessStepProvider extends ChangeNotifier implements AdminProcessStepProvider {
  // State fields
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
  String? _failureErrorMessage;
  String? _presetDeactivateErrorMessage;

  // Control flags for tests
  bool _deactivateSuccess = true;
  int fetchCallCount = 0;

  void setDeactivateResult(bool success, {String? errorMessage}) {
    _deactivateSuccess = success;
    _failureErrorMessage = errorMessage;
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
    return true;
  }

  @override
  Future<bool> updateProcessStep({required String id, required String name, required int stepOrder}) async {
    return true;
  }

  @override
  Future<void> fetchProcessSteps() async {
    fetchCallCount++;
  }

  @override
  Future<bool> deactivateProcessStep(String id) async {
    _isDeactivating = true;
    // Clear any prior error before starting a new attempt
    _deactivateErrorMessage = null;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 10));
    _isDeactivating = false;
    if (!_deactivateSuccess) {
      // Use the error message set via setDeactivateResult
      _deactivateErrorMessage = _failureErrorMessage ?? 'Deactivate failed';
    }
    notifyListeners();
    if (_deactivateSuccess) await fetchProcessSteps();
    return _deactivateSuccess;
  }

  @override
  Future<bool> reactivateProcessStep(String id) async {
    return true;
  }

  FakeAdminProcessStepProvider({required String dummy});
}

void main() {
  late FakeAdminProcessStepProvider fakeProvider;

  setUp(() {
    fakeProvider = FakeAdminProcessStepProvider(dummy: '');
    fakeProvider._isLoading = false;
    fakeProvider._errorMessage = null;
    fakeProvider.activeSteps = [
      ProcessStep(
        id: '1',
        name: 'Step One',
        stepOrder: 1,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
    fakeProvider.inactiveSteps = [];
    fakeProvider._isCreating = false;
    fakeProvider._isUpdating = false;
    fakeProvider._isDeactivating = false;
    fakeProvider._createErrorMessage = null;
    fakeProvider._updateErrorMessage = null;
    fakeProvider._deactivateErrorMessage = null;
    fakeProvider.setDeactivateResult(true);
    fakeProvider.fetchCallCount = 0;
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

  testWidgets('Deactivate dialog opens when Deactivate button tapped', (tester) async {
    await pumpScreen(tester);
    expect(find.byTooltip('Deactivate step'), findsOneWidget);
    await tester.tap(find.byTooltip('Deactivate step'));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate Process Step'), findsOneWidget);
  });

  testWidgets('Cancel button closes dialog', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('Deactivate step'));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate Process Step'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate Process Step'), findsNothing);
  });

  testWidgets('Successful deactivation closes dialog and shows SnackBar', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('Deactivate step'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Deactivate'));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate Process Step'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Process step deactivated'), findsOneWidget);
    expect(fakeProvider.fetchCallCount, greaterThan(0));
  });

  testWidgets('Loading state shows progress indicator and disables button', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('Deactivate step'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Deactivate'));
    await tester.pump();
    final button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Deactivate'));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Error message stays visible on failure', (tester) async {
    fakeProvider.setDeactivateResult(false, errorMessage: 'Cannot deactivate');
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('Deactivate step'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Deactivate'));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate Process Step'), findsOneWidget);
    expect(find.text('Cannot deactivate'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}
