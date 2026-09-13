import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/widgets/common/app_scaffold.dart';
import 'package:frontend/widgets/common/primary_action_button.dart';
import 'package:frontend/widgets/common/status_chip.dart';
import 'package:frontend/widgets/glass/glass_card.dart';

void main() {
  group('GlassCard Widget Tests', () {
    testWidgets('Renders child content and triggers onTap callback', (
      tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassCard(
              onTap: () => tapped = true,
              child: const Text('Industrial Door Step 1'),
            ),
          ),
        ),
      );

      expect(find.text('Industrial Door Step 1'), findsOneWidget);

      await tester.tap(find.text('Industrial Door Step 1'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('PrimaryActionButton Widget Tests', () {
    testWidgets(
      'Renders button label and triggers onPressed when not loading',
      (tester) async {
        bool pressed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PrimaryActionButton(
                label: 'Complete Step',
                onPressed: () => pressed = true,
              ),
            ),
          ),
        );

        expect(find.text('Complete Step'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        await tester.tap(find.text('Complete Step'));
        await tester.pumpAndSettle();

        expect(pressed, isTrue);
      },
    );

    testWidgets(
      'Shows CircularProgressIndicator and ignores tap when isLoading is true',
      (tester) async {
        bool pressed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PrimaryActionButton(
                label: 'Complete Step',
                isLoading: true,
                onPressed: () => pressed = true,
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Complete Step'), findsNothing);

        await tester.tap(find.byType(CircularProgressIndicator));
        await tester.pump();

        expect(pressed, isFalse);
      },
    );
  });

  group('StatusChip Widget Tests', () {
    testWidgets('Renders status chip variants with expected labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusChip.pending(),
                StatusChip.completed(),
                StatusChip.cancelled(),
                StatusChip.inProgress(),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
    });
  });

  group('AppScaffold Widget Tests', () {
    testWidgets('Renders title and body inside styled scaffold', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AppScaffold(
            title: 'Station 4 - Assembly',
            body: Text('Assembly in progress'),
          ),
        ),
      );

      expect(find.text('Station 4 - Assembly'), findsOneWidget);
      expect(find.text('Assembly in progress'), findsOneWidget);
    });
  });
}
