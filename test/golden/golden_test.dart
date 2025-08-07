import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hands_app/features/auth/pages/login_page.dart';
import 'package:hands_app/features/dashboard/pages/admin_dashboard_page.dart';
import 'package:hands_app/theme/theme.dart';

void main() {
  group('Golden Tests - Responsive Layout', () {
    testWidgets('Login page golden test 320dp', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));

      await tester.pumpWidget(MaterialApp(theme: handsTheme, home: const LoginPage()));
      await tester.pumpAndSettle();

      await expectLater(find.byType(MaterialApp), matchesGoldenFile('golden/login_320dp.png'));
    });

    testWidgets('Login page golden test 390dp', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(MaterialApp(theme: handsTheme, home: const LoginPage()));
      await tester.pumpAndSettle();

      await expectLater(find.byType(MaterialApp), matchesGoldenFile('golden/login_390dp.png'));
    });

    testWidgets('Login page golden test 600dp', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1024));

      await tester.pumpWidget(MaterialApp(theme: handsTheme, home: const LoginPage()));
      await tester.pumpAndSettle();

      await expectLater(find.byType(MaterialApp), matchesGoldenFile('golden/login_600dp.png'));
    });

    testWidgets('Admin dashboard golden test 320dp', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));

      await tester.pumpWidget(MaterialApp(theme: handsTheme, home: const AdminDashboardPage()));
      await tester.pumpAndSettle();

      await expectLater(find.byType(MaterialApp), matchesGoldenFile('golden/admin_dashboard_320dp.png'));
    });

    testWidgets('Admin dashboard golden test 390dp', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(MaterialApp(theme: handsTheme, home: const AdminDashboardPage()));
      await tester.pumpAndSettle();

      await expectLater(find.byType(MaterialApp), matchesGoldenFile('golden/admin_dashboard_390dp.png'));
    });

    testWidgets('Admin dashboard golden test 600dp', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1024));

      await tester.pumpWidget(MaterialApp(theme: handsTheme, home: const AdminDashboardPage()));
      await tester.pumpAndSettle();

      await expectLater(find.byType(MaterialApp), matchesGoldenFile('golden/admin_dashboard_600dp.png'));
    });

    testWidgets('Text scaling golden test - 2.0x scale', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        MaterialApp(
          theme: handsTheme,
          home: MediaQuery(data: const MediaQueryData(textScaler: TextScaler.linear(2.0)), child: const LoginPage()),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(find.byType(MaterialApp), matchesGoldenFile('golden/login_2x_text_scale.png'));
    });

    testWidgets('Text scaling golden test - 3.0x scale', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        MaterialApp(
          theme: handsTheme,
          home: MediaQuery(data: const MediaQueryData(textScaler: TextScaler.linear(3.0)), child: const LoginPage()),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(find.byType(MaterialApp), matchesGoldenFile('golden/login_3x_text_scale.png'));
    });
  });
}
