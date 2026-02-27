import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflect_os/features/auth/screens/login_screen.dart';

void main() {
  group('LoginScreen', () {
    // Give the test surface enough width so the Row at the bottom doesn't overflow.
    void useWideScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    Widget buildSubject() => const ProviderScope(
          child: MaterialApp(home: LoginScreen()),
        );

    testWidgets('renders email field', (tester) async {
      useWideScreen(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    });

    testWidgets('renders password field', (tester) async {
      useWideScreen(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    });

    testWidgets('renders Sign in button when not loading', (tester) async {
      useWideScreen(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('Sign in button is tappable when not loading', (tester) async {
      useWideScreen(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'Sign in');
      expect(button, findsOneWidget);
      final widget = tester.widget<FilledButton>(button);
      expect(widget.onPressed, isNotNull);
    });
  });
}
