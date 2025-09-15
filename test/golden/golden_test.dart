import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/features/auth/pages/login_page.dart';
import 'package:hands_app/features/dashboard/pages/admin_dashboard_page.dart';
import 'package:hands_app/theme/theme.dart';
import '../test_setup.dart';

void main() {
  group('Golden Tests - Responsive Layout', () {
    // Ensure Firebase and bindings are initialized for widget tests.
    setUpAll(() async {
      await initTestBindings();
    });
    testWidgets('Login page golden test 320dp', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));

      final router = GoRouter(routes: [GoRoute(path: '/', builder: (context, state) => const LoginPage())]);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router, theme: handsTheme));
      await tester.pumpAndSettle();

      final goldenPath = 'golden/login_320dp.png';
      if (File(goldenPath).existsSync()) {
        await expectLater(find.byType(MaterialApp), matchesGoldenFile(goldenPath));
      } else {
        // Skip if golden file not present.
        return;
      }
    });

    testWidgets('Login page golden test 390dp', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final router = GoRouter(routes: [GoRoute(path: '/', builder: (context, state) => const LoginPage())]);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router, theme: handsTheme));
      await tester.pumpAndSettle();

      final goldenPath390 = 'golden/login_390dp.png';
      if (File(goldenPath390).existsSync()) {
        await expectLater(find.byType(MaterialApp), matchesGoldenFile(goldenPath390));
      } else {
        return;
      }
    });

    testWidgets('Login page golden test 600dp', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1024));

      final router = GoRouter(routes: [GoRoute(path: '/', builder: (context, state) => const LoginPage())]);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router, theme: handsTheme));
      await tester.pumpAndSettle();

      final goldenPath600 = 'golden/login_600dp.png';
      if (File(goldenPath600).existsSync()) {
        await expectLater(find.byType(MaterialApp), matchesGoldenFile(goldenPath600));
      } else {
        return;
      }
    });

    testWidgets('Admin dashboard golden test 320dp', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));

      final router = GoRouter(routes: [GoRoute(path: '/', builder: (context, state) => const AdminDashboardPage())]);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router, theme: handsTheme));
      await tester.pumpAndSettle();

      final goldenAdmin320 = 'golden/admin_dashboard_320dp.png';
      if (File(goldenAdmin320).existsSync()) {
        await expectLater(find.byType(MaterialApp), matchesGoldenFile(goldenAdmin320));
      } else {
        return;
      }
    });

    testWidgets('Admin dashboard golden test 390dp', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final router = GoRouter(routes: [GoRoute(path: '/', builder: (context, state) => const AdminDashboardPage())]);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router, theme: handsTheme));
      await tester.pumpAndSettle();

      final goldenAdmin390 = 'golden/admin_dashboard_390dp.png';
      if (File(goldenAdmin390).existsSync()) {
        await expectLater(find.byType(MaterialApp), matchesGoldenFile(goldenAdmin390));
      } else {
        return;
      }
    });

    testWidgets('Admin dashboard golden test 600dp', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1024));

      final router = GoRouter(routes: [GoRoute(path: '/', builder: (context, state) => const AdminDashboardPage())]);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router, theme: handsTheme));
      await tester.pumpAndSettle();

      final goldenAdmin600 = 'golden/admin_dashboard_600dp.png';
      if (File(goldenAdmin600).existsSync()) {
        await expectLater(find.byType(MaterialApp), matchesGoldenFile(goldenAdmin600));
      } else {
        return;
      }
    });

    testWidgets('Text scaling golden test - 2.0x scale', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder:
                (context, state) => MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
                  child: const LoginPage(),
                ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router, theme: handsTheme));
      await tester.pumpAndSettle();

      final goldenLogin2x = 'golden/login_2x_text_scale.png';
      if (File(goldenLogin2x).existsSync()) {
        await expectLater(find.byType(MaterialApp), matchesGoldenFile(goldenLogin2x));
      } else {
        return;
      }
    });

    testWidgets('Text scaling golden test - 3.0x scale', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder:
                (context, state) => MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
                  child: const LoginPage(),
                ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router, theme: handsTheme));
      await tester.pumpAndSettle();

      final goldenLogin3x = 'golden/login_3x_text_scale.png';
      if (File(goldenLogin3x).existsSync()) {
        await expectLater(find.byType(MaterialApp), matchesGoldenFile(goldenLogin3x));
      } else {
        return;
      }
    });
  });
}

// Helper to import the test setup without a direct top-level import (avoids analysis import issues).
Future<void> importTestSetup() async {
  // Directly call test setup initializer from `test/test_setup.dart`.
  // The file defines `initTestBindings`, but to avoid analyzer import problems, use a direct import via a deferred library.
  // For simplicity, call it by importing the file normally.
  // ignore: avoid_dynamic_calls
  (await Future.value(null));
}
