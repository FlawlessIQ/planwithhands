// Test script to verify token fixes
// Run this after signing in to verify tokens are stored correctly

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/services/push_notification_service.dart';
import 'package:hands_app/debug_push_test.dart';

class TokenFixTestWidget extends StatefulWidget {
  @override
  _TokenFixTestWidgetState createState() => _TokenFixTestWidgetState();
}

class _TokenFixTestWidgetState extends State<TokenFixTestWidget> {
  String _testResult = 'Not tested yet';

  Future<void> _runTokenTest() async {
    setState(() {
      _testResult = 'Running test...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _testResult = 'Error: No user signed in';
        });
        return;
      }

      // Test token registration
      await PushNotificationService().ensureRegistered();

      // Run diagnostics
      await PushNotificationDebugger.runDiagnostics(user.uid);

      setState(() {
        _testResult = 'Test completed! Check console for details.';
      });
    } catch (e) {
      setState(() {
        _testResult = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Token Fix Test')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FCM Token Storage Fix Test', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text(
              'This test verifies that FCM tokens are stored in user-specific paths instead of top-level collections.',
            ),
            SizedBox(height: 16),
            Text('Expected behavior:'),
            Text('• Tokens stored in users/{uid}/deviceTokens/{tokenHash}'),
            Text('• lastFcmToken updated on user document'),
            Text('• Old tokens marked as inactive'),
            SizedBox(height: 20),
            ElevatedButton(onPressed: _runTokenTest, child: Text('Run Token Test')),
            SizedBox(height: 16),
            Text('Result:'),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
              child: Text(_testResult),
            ),
          ],
        ),
      ),
    );
  }
}
