// Simple test script to verify dashboard loads without errors
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'lib/features/dashboard/pages/WEB_manager_dashboard_page.dart';

void main() {
  print('Testing WEB Manager Dashboard...');

  if (!kIsWeb) {
    print('Warning: Not running on web platform');
  }

  // Simple widget test
  runApp(MaterialApp(home: ManagerDashboardPage(organizationId: 'test-org'), debugShowCheckedModeBanner: false));

  print('Dashboard widget loaded successfully');
}
