import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflect_os/features/decisions/data/models/category.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';
import 'package:reflect_os/features/decisions/screens/create_decision_screen.dart';
import 'package:reflect_os/features/settings/providers/vertical_provider.dart';

void main() {
  group('CreateDecisionScreen', () {
    testWidgets('renders without throwing (smoke test)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Prevent Supabase calls during build by stubbing providers
            categoriesProvider.overrideWith(
              (ref) async => <Category>[],
            ),
            currentVerticalProvider.overrideWith(
              (ref) async => null,
            ),
          ],
          child: const MaterialApp(home: CreateDecisionScreen()),
        ),
      );
      // Allow async providers to settle
      await tester.pump();
      // Screen rendered — check for a static element present regardless of state
      expect(find.text('New Decision'), findsOneWidget);
    });

    testWidgets('shows Save action in app bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) async => <Category>[]),
            currentVerticalProvider.overrideWith((ref) async => null),
          ],
          child: const MaterialApp(home: CreateDecisionScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('Save'), findsOneWidget);
    });
  });
}
