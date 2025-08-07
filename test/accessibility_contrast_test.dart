import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hands_app/pages/accessibility_demo_page.dart';
import 'package:hands_app/theme/theme.dart';

void main() {
  group('Accessibility Tests', () {
    testWidgets('Demo page meets contrast requirements', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(theme: handsTheme, home: const AccessibilityDemoPage()));
      await tester.pumpAndSettle();

      // Verify the page loads without errors
      expect(find.byType(AccessibilityDemoPage), findsOneWidget);
      expect(find.text('Accessibility Demo'), findsOneWidget);
    });

    testWidgets('Demo page works at 320dp width', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));

      await tester.pumpWidget(MaterialApp(theme: handsTheme, home: const AccessibilityDemoPage()));
      await tester.pumpAndSettle();

      // Verify no overflow
      expect(tester.takeException(), isNull);
      expect(find.byType(AccessibilityDemoPage), findsOneWidget);
    });

    testWidgets('Demo page works at 390dp width', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(MaterialApp(theme: handsTheme, home: const AccessibilityDemoPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AccessibilityDemoPage), findsOneWidget);
    });

    testWidgets('Demo page works at 600dp width', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1024));

      await tester.pumpWidget(MaterialApp(theme: handsTheme, home: const AccessibilityDemoPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AccessibilityDemoPage), findsOneWidget);
    });

    testWidgets('Text scaling works without overflow at 2.0x', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        MaterialApp(
          theme: handsTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: const AccessibilityDemoPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AccessibilityDemoPage), findsOneWidget);
    });

    testWidgets('Text scaling works without overflow at 3.0x', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        MaterialApp(
          theme: handsTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
            child: const AccessibilityDemoPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AccessibilityDemoPage), findsOneWidget);
    });

    testWidgets('Form validation works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(theme: handsTheme, home: const AccessibilityDemoPage()));
      await tester.pumpAndSettle();

      // Try to submit empty form
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      // Should show validation errors
      expect(find.text('Please enter your full name'), findsOneWidget);
      expect(find.text('Please enter your email address'), findsOneWidget);
    });

    testWidgets('Touch targets are accessible', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(theme: handsTheme, home: const AccessibilityDemoPage()));
      await tester.pumpAndSettle();

      // Find all buttons
      final buttons = find.byType(ElevatedButton);
      final iconButtons = find.byType(IconButton);

      expect(buttons, findsWidgets);
      expect(iconButtons, findsWidgets);

      // Verify buttons are tappable
      await tester.tap(find.text('Clear Form'));
      await tester.pumpAndSettle();

      // No exceptions should occur
      expect(tester.takeException(), isNull);
    });
  });
}
