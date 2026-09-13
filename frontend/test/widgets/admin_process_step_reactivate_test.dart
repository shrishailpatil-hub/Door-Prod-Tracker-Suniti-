import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:frontend/models/admin/process_step.dart';
import 'package:frontend/providers/admin_process_step_provider.dart';
import 'package:frontend/screens/admin/admin_process_step_list_screen.dart';

class MockAdminProcessStepProvider extends Mock
    implements AdminProcessStepProvider {}

void main() {
  late MockAdminProcessStepProvider mockProvider;

  final activeStep = ProcessStep(
    id: 's1',
    name: 'Cutting',
    stepOrder: 1,
    isActive: true,
    createdAt: DateTime.parse('2026-09-10T10:00:00.000Z'),
    updatedAt: DateTime.parse('2026-09-10T10:00:00.000Z'),
  );

  final inactiveStep = ProcessStep(
    id: 's2',
    name: 'Polishing',
    stepOrder: 2,
    isActive: false,
    createdAt: DateTime.parse('2026-09-10T10:00:00.000Z'),
    updatedAt: DateTime.parse('2026-09-10T10:00:00.000Z'),
  );

  setUp(() {
    mockProvider = MockAdminProcessStepProvider();

    when(() => mockProvider.isLoading).thenReturn(false);
    when(() => mockProvider.errorMessage).thenReturn(null);
    when(() => mockProvider.steps).thenReturn([activeStep, inactiveStep]);
    when(() => mockProvider.activeSteps).thenReturn([activeStep]);
    when(() => mockProvider.inactiveSteps).thenReturn([inactiveStep]);
    when(() => mockProvider.isReactivating).thenReturn(false);
    when(() => mockProvider.reactivateErrorMessage).thenReturn(null);
    when(() => mockProvider.fetchProcessSteps()).thenAnswer((_) async {});
  });

  Widget buildScreen() {
    return MaterialApp(
      home: ChangeNotifierProvider<AdminProcessStepProvider>.value(
        value: mockProvider,
        child: const AdminProcessStepListScreen(),
      ),
    );
  }

  testWidgets('1. Inactive Process Step displays Reactivate action button', (tester) async {
    await tester.pumpWidget(buildScreen());

    expect(find.text('Polishing'), findsOneWidget);
    expect(find.text('Reactivate'), findsOneWidget);
    expect(find.byKey(const Key('reactivateButton_s2')), findsOneWidget);
  });

  testWidgets('2. Tapping Reactivate opens confirmation dialog with correct message', (tester) async {
    await tester.pumpWidget(buildScreen());

    await tester.tap(find.byKey(const Key('reactivateButton_s2')));
    await tester.pumpAndSettle();

    expect(find.text('Reactivate Process Step'), findsOneWidget);
    expect(
      find.text('Are you sure you want to reactivate "Polishing"?\n\nIt will be added to the end of the active process steps.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    expect(find.byKey(const Key('confirmReactivateButton')), findsOneWidget);
  });

  testWidgets('3. Cancel button closes dialog without reactivating', (tester) async {
    await tester.pumpWidget(buildScreen());

    await tester.tap(find.byKey(const Key('reactivateButton_s2')));
    await tester.pumpAndSettle();

    expect(find.text('Reactivate Process Step'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Reactivate Process Step'), findsNothing);
    verifyNever(() => mockProvider.reactivateProcessStep(any()));
  });

  testWidgets('4. Successful reactivation calls provider and shows SnackBar', (tester) async {
    when(() => mockProvider.reactivateProcessStep('s2')).thenAnswer((_) async => true);

    await tester.pumpWidget(buildScreen());

    await tester.tap(find.byKey(const Key('reactivateButton_s2')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmReactivateButton')));
    await tester.pumpAndSettle();

    verify(() => mockProvider.reactivateProcessStep('s2')).called(1);
    expect(find.text('Reactivate Process Step'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Process step "Polishing" reactivated'), findsOneWidget);
  });

  testWidgets('5. Failure in provider does not close dialog and displays error message', (tester) async {
    when(() => mockProvider.reactivateProcessStep('s2')).thenAnswer((_) async {
      when(() => mockProvider.reactivateErrorMessage).thenReturn('Active process step name already exists');
      return false;
    });

    await tester.pumpWidget(buildScreen());

    await tester.tap(find.byKey(const Key('reactivateButton_s2')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmReactivateButton')));
    await tester.pump();

    verify(() => mockProvider.reactivateProcessStep('s2')).called(1);
    expect(find.text('Reactivate Process Step'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}
