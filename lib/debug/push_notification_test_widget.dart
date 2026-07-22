import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/services/push_notification_service.dart';
import 'package:hands_app/features/messaging/services/token_registration_service.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class PushNotificationTestWidget extends ConsumerStatefulWidget {
  const PushNotificationTestWidget({super.key});

  @override
  ConsumerState<PushNotificationTestWidget> createState() => _PushNotificationTestWidgetState();
}

class _PushNotificationTestWidgetState extends ConsumerState<PushNotificationTestWidget> {
  final PushNotificationService _notificationService = PushNotificationService();
  String _testResults = '';
  bool _isRunning = false;
  String? _currentToken;
  String? _userId;
  Map<String, dynamic> _tokenData = {};

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  void _getCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
    }
  }

  Future<void> _runFullDiagnostics() async {
    setState(() {
      _isRunning = true;
      _testResults = 'Running push notification diagnostics...\n\n';
    });

    try {
      // Test 1: Check user authentication
      await _testUserAuth();

      // Test 2: Check FCM token generation
      await _testTokenGeneration();

      // Test 3: Check permission status
      await _testPermissionStatus();

      // Test 4: Check token storage in Firestore
      await _testTokenStorage();

      // Test 5: Test token registration service
      await _testTokenRegistration();

      // Test 6: Check notification settings
      await _testNotificationSettings();

      _addResult('\n✅ Diagnostics complete!');
    } catch (e) {
      _addResult('\n❌ Error during diagnostics: $e');
      logger.e('[PushNotificationTest] Diagnostics error', e);
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _testUserAuth() async {
    _addResult('🔍 Checking user authentication...');
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _addResult('✅ User authenticated: ${user.uid}');
      setState(() {
        _userId = user.uid;
      });
    } else {
      _addResult('❌ No authenticated user found');
    }
  }

  Future<void> _testTokenGeneration() async {
    _addResult('\n🔍 Testing FCM token generation...');
    try {
      final token = await _notificationService.getToken();
      if (token != null) {
        _addResult('✅ FCM token generated: ${token.substring(0, 20)}...');
        setState(() {
          _currentToken = token;
        });
      } else {
        _addResult('❌ Failed to generate FCM token');
      }
    } catch (e) {
      _addResult('❌ Error generating token: $e');
    }
  }

  Future<void> _testPermissionStatus() async {
    _addResult('\n🔍 Checking notification permissions...');
    try {
      final result = await _notificationService.checkPermissionStatus();
      _addResult('📱 Permission status: ${result.name}');
      _addResult('📝 Message: ${result.message}');

      if (!result.isGranted) {
        _addResult('⚠️  Permissions not granted - notifications may not work');
      }
    } catch (e) {
      _addResult('❌ Error checking permissions: $e');
    }
  }

  Future<void> _testTokenStorage() async {
    _addResult('\n🔍 Checking token storage in Firestore...');
    if (_userId == null) {
      _addResult('❌ Cannot check storage - no user ID');
      return;
    }

    try {
      // Check user-specific token collection
      final tokensSnapshot =
          await FirestoreEnforcer.instance
              .collection('users')
              .doc(_userId!)
              .collection('deviceTokens')
              .where('isActive', isEqualTo: true)
              .get();

      if (tokensSnapshot.docs.isNotEmpty) {
        _addResult('✅ Found ${tokensSnapshot.docs.length} active tokens in user collection');
        for (var doc in tokensSnapshot.docs) {
          final data = doc.data();
          _addResult('  📱 Platform: ${data['platform']}, Updated: ${data['updatedAt']}');
          setState(() {
            _tokenData = data;
          });
        }
      } else {
        _addResult('⚠️  No active tokens found in user collection');
      }

      // Check user document for lastFcmToken
      final userDoc = await FirestoreEnforcer.instance.collection('users').doc(_userId!).get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        if (userData.containsKey('lastFcmToken')) {
          _addResult('✅ lastFcmToken found on user document');
        } else {
          _addResult('⚠️  lastFcmToken not found on user document');
        }
      }

      // Check legacy collection (should be empty for new users)
      final legacySnapshot =
          await FirestoreEnforcer.instance
              .collection('deviceTokens')
              .where('userId', isEqualTo: _userId!)
              .where('isActive', isEqualTo: true)
              .get();

      if (legacySnapshot.docs.isNotEmpty) {
        _addResult('⚠️  Found ${legacySnapshot.docs.length} tokens in legacy collection');
      } else {
        _addResult('✅ No tokens in legacy collection (good!)');
      }
    } catch (e) {
      _addResult('❌ Error checking token storage: $e');
    }
  }

  Future<void> _testTokenRegistration() async {
    _addResult('\n🔍 Testing token registration service...');
    if (_userId == null) {
      _addResult('❌ Cannot test registration - no user ID');
      return;
    }

    try {
      await TokenRegistrationService.registerCurrentDevice(_userId!);
      _addResult('✅ Token registration service completed');

      // Re-check storage after registration
      await Future.delayed(const Duration(seconds: 1));
      await _testTokenStorage();
    } catch (e) {
      _addResult('❌ Error during token registration: $e');
    }
  }

  Future<void> _testNotificationSettings() async {
    _addResult('\n🔍 Getting detailed notification settings...');
    try {
      final settings = await _notificationService.getNotificationSettings();
      if (settings.isNotEmpty) {
        _addResult('📋 Notification Settings:');
        settings.forEach((key, value) {
          _addResult('  $key: $value');
        });
      } else {
        _addResult('⚠️  Could not retrieve notification settings');
      }
    } catch (e) {
      _addResult('❌ Error getting notification settings: $e');
    }
  }

  void _addResult(String message) {
    setState(() {
      _testResults += '$message\n';
    });
    logger.d('[PushNotificationTest] $message');
  }

  Future<void> _requestPermissions() async {
    try {
      _addResult('\n🔍 Requesting notification permissions...');
      final result = await _notificationService.requestPermissionWithContext(context: 'debug_test');
      _addResult('📱 Permission result: ${result.name}');

      if (result.isGranted) {
        _addResult('✅ Permissions granted - running token registration...');
        await _notificationService.ensureRegistered();
        _addResult('✅ Token registration completed');
      }
    } catch (e) {
      _addResult('❌ Error requesting permissions: $e');
    }
  }

  void _copyTokenToClipboard() {
    if (_currentToken != null) {
      Clipboard.setData(ClipboardData(text: _currentToken!));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FCM token copied to clipboard')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Push Notification Test'),
        actions: [
          if (_currentToken != null)
            IconButton(icon: const Icon(Icons.copy), onPressed: _copyTokenToClipboard, tooltip: 'Copy FCM Token'),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _runFullDiagnostics,
                    icon:
                        _isRunning
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.play_arrow),
                    label: Text(_isRunning ? 'Running...' : 'Run Diagnostics'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _requestPermissions,
                  icon: const Icon(Icons.notifications),
                  label: const Text('Request Permissions'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_userId != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User ID: $_userId', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (_currentToken != null) ...[
                        const SizedBox(height: 4),
                        Text('FCM Token: ${_currentToken!.substring(0, 30)}...'),
                      ],
                      if (_tokenData.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Platform: ${_tokenData['platform']}'),
                        Text('Active: ${_tokenData['isActive']}'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Test Results:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            _testResults.isEmpty ? 'Tap "Run Diagnostics" to start testing...' : _testResults,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
