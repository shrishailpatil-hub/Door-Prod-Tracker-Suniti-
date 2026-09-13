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

  final step1 = ProcessStep(
    id: 's1',
    name: 'Cutting',
    stepOrder: 1,
    isActive: true,
    createdAt: DateTime.parse('2026-09-10T10:00:00.000Z'),
    updatedAt: DateTime.parse('2026-09-10T10:00:00.000Z'),
  );

  final step2 = ProcessStep(
    id: 's2',
    name: 'Welding',
    stepOrder: 2,
    isActive: true,
    createdAt: DateTime.parse('2026-09-10T10:00:00.000Z'),
    updatedAt: DateTime.parse('2026-09-10T10:00:00.000Z'),
  );

  final inactiveStep = ProcessStep(
    id: 's3',
    name: 'Old Priming',
    stepOrder: 5,
    isActive: false,
    createdAt: DateTime.parse('2026-08-01T10:00:00.000Z'),
    updatedAt: DateTime.parse('2026-08-05T10:00:00.000Z'),
  );

  setUp(() {
    mockProvider = MockAdminProcessStepProvider();

    when(() => mockProvider.isLoading).thenReturn(false);
    when(() => mockProvider.errorMessage).thenReturn(null);
    when(() => mockProvider.steps).thenReturn([]);
    when(() => mockProvider.activeSteps).thenReturn([]);
    when(() => mockProvider.inactiveSteps).thenReturn([]);
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

  group('AdminProcessStepListScreen Widget Tests', () {
    testWidgets('1. Screen renders Process Steps title and back button', (tester) async {
      await tester.pumpWidget(buildScreen());

      expect(find.text('Process Steps'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('2 & 3. Active steps are displayed in stepOrder ASC', (tester) async {
      when(() => mockProvider.activeSteps).thenReturn([step1, step2]);
      when(() => mockProvider.steps).thenReturn([step1, step2]);

      await tester.pumpWidget(buildScreen());

      expect(find.text('Cutting'), findsOneWidget);
      expect(find.text('Welding'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('ACTIVE PROCESS FLOW'), findsOneWidget);

      // Verify visual order: Cutting appears above Welding
      final cuttingTop = tester.getTopLeft(find.text('Cutting')).dy;
      final weldingTop = tester.getTopLeft(find.text('Welding')).dy;
      expect(cuttingTop, lessThan(weldingTop));
    });

    testWidgets('4. ACTIVE status chip is visible for active steps', (tester) async {
      when(() => mockProvider.activeSteps).thenReturn([step1]);
      when(() => mockProvider.steps).thenReturn([step1]);

      await tester.pumpWidget(buildScreen());

      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('5 & 6 & 7. Inactive steps displayed separately with INACTIVE status', (tester) async {
      when(() => mockProvider.activeSteps).thenReturn([step1]);
      when(() => mockProvider.inactiveSteps).thenReturn([inactiveStep]);
      when(() => mockProvider.steps).thenReturn([step1, inactiveStep]);

      await tester.pumpWidget(buildScreen());

      expect(find.text('INACTIVE STEPS'), findsOneWidget);
      expect(find.text('Old Priming'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.text('Previous order: 5'), findsOneWidget);

      // Inactive step is placed below active section
      final activeHeaderTop = tester.getTopLeft(find.text('ACTIVE PROCESS FLOW')).dy;
      final inactiveHeaderTop = tester.getTopLeft(find.text('INACTIVE STEPS')).dy;
      expect(activeHeaderTop, lessThan(inactiveHeaderTop));
    });

    testWidgets('8. Loading state is displayed while fetching', (tester) async {
      when(() => mockProvider.isLoading).thenReturn(true);

      await tester.pumpWidget(buildScreen());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No active process steps'), findsNothing);
    });

    testWidgets('9. Empty state appears after fetch with zero active steps', (tester) async {
      when(() => mockProvider.isLoading).thenReturn(false);
      when(() => mockProvider.activeSteps).thenReturn([]);
      when(() => mockProvider.inactiveSteps).thenReturn([]);
      when(() => mockProvider.steps).thenReturn([]);

      await tester.pumpWidget(buildScreen());

      expect(find.text('No active process steps'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('10 & 11. Provider error is displayed with Retry invoking fetchProcessSteps', (tester) async {
      when(() => mockProvider.isLoading).thenReturn(false);
      when(() => mockProvider.errorMessage).thenReturn('Failed to load process steps');

      await tester.pumpWidget(buildScreen());

      expect(find.text('Failed to load process steps'), findsOneWidget);
      final retryButton = find.text('Retry');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      await tester.pump();

      verify(() => mockProvider.fetchProcessSteps()).called(greaterThanOrEqualTo(1));
    });

    testWidgets('12. Add/Create action exists in AppBar', (tester) async {
      await tester.pumpWidget(buildScreen());

      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      expect(find.byTooltip('Add Process Step'), findsOneWidget);
    });

    testWidgets('13 & 14. Edit and Deactivate actions exist for active steps', (tester) async {
      when(() => mockProvider.activeSteps).thenReturn([step1]);
      when(() => mockProvider.steps).thenReturn([step1]);

      await tester.pumpWidget(buildScreen());

      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byTooltip('Edit step'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byTooltip('Deactivate step'), findsOneWidget);
    });

    testWidgets('15. Pull-to-refresh invokes provider fetch', (tester) async {
      when(() => mockProvider.activeSteps).thenReturn([step1]);
      when(() => mockProvider.steps).thenReturn([step1]);

      await tester.pumpWidget(buildScreen());

      await tester.fling(find.byType(ListView), const Offset(0.0, 300.0), 1000.0);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(() => mockProvider.fetchProcessSteps()).called(greaterThanOrEqualTo(1));
    });
  });
}
