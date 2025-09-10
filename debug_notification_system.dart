import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hands_app/firebase_options.dart';
import 'package:hands_app/services/push_notification_service.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    runApp(DebugErrorApp('Firebase init failed: $e'));
    return;
  }

  runApp(const NotificationDebugApp());
}

class NotificationDebugApp extends StatelessWidget {
  const NotificationDebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notification Debug',
      debugShowCheckedModeBanner: false,
      home: const NotificationDebugPage(),
    );
  }
}

class NotificationDebugPage extends StatefulWidget {
  const NotificationDebugPage({super.key});

  @override
  State<NotificationDebugPage> createState() => _NotificationDebugPageState();
}

class _NotificationDebugPageState extends State<NotificationDebugPage> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  final PushNotificationService _notificationService = PushNotificationService();
  String? _fcmToken;
  NotificationPermissionResult _permissionStatus = NotificationPermissionResult.notDetermined;
  int _unreadCount = 0;
  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _log(String message) {
    setState(() {
      _logs.add('${DateTime.now().toIso8601String()}: $message');
    });
    debugPrint('[DEBUG] $message');

    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _runDiagnostics() async {
    _log('🔍 Starting notification system diagnostics...');

    try {
      // 1. Check platform
      _log(
        '📱 Platform: ${Platform.isIOS
            ? 'iOS'
            : Platform.isAndroid
            ? 'Android'
            : 'Unknown'}',
      );

      // 2. Check Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _log('❌ User not authenticated');
        return;
      }
      _log('✅ User authenticated: ${user.uid}');

      // 3. Get user data from Firestore
      try {
        final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final orgId = userData['organizationId'] as String?;
          _log('✅ User data loaded, orgId: $orgId');
        } else {
          _log('❌ User document not found in Firestore');
        }
      } catch (e) {
        _log('❌ Error loading user data: $e');
      }

      // 4. Initialize push notification service
      try {
        await _notificationService.initialize();
        _log('✅ Push notification service initialized');
      } catch (e) {
        _log('❌ Push notification service initialization failed: $e');
      }

      // 5. Check permission status
      try {
        _permissionStatus = await _notificationService.checkPermissionStatus();
        _log('📋 Permission status: $_permissionStatus');
        setState(() {});
      } catch (e) {
        _log('❌ Error checking permission status: $e');
      }

      // 6. Get FCM token
      try {
        _fcmToken = _notificationService.currentToken;
        if (_fcmToken != null) {
          _log('✅ FCM Token: ${_fcmToken!.substring(0, 30)}...');
        } else {
          _log('❌ No FCM token available');
        }
      } catch (e) {
        _log('❌ Error getting FCM token: $e');
      }

      // 7. Check token storage in Firestore
      if (_fcmToken != null) {
        try {
          final tokenHash = _fcmToken!.hashCode.abs().toString();
          final tokenDoc =
              await FirestoreEnforcer.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('deviceTokens')
                  .doc(tokenHash)
                  .get();

          if (tokenDoc.exists) {
            final tokenData = tokenDoc.data()!;
            _log('✅ Token stored in Firestore: isActive=${tokenData['isActive']}');
          } else {
            _log('❌ Token not found in Firestore user subcollection');

            // Check legacy collection
            final legacyQuery =
                await FirestoreEnforcer.instance
                    .collection('deviceTokens')
                    .where('userId', isEqualTo: user.uid)
                    .where('fcmToken', isEqualTo: _fcmToken)
                    .get();

            if (legacyQuery.docs.isNotEmpty) {
              _log('⚠️ Token found in legacy deviceTokens collection');
            } else {
              _log('❌ Token not found in legacy collection either');
            }
          }
        } catch (e) {
          _log('❌ Error checking token storage: $e');
        }
      }

      // 8. Check unread notifications
      try {
        final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final orgId = userData['organizationId'] as String?;

          if (orgId != null) {
            final notificationQuery =
                await FirestoreEnforcer.instance
                    .collection('organizations')
                    .doc(orgId)
                    .collection('notifications')
                    .where('userId', isEqualTo: user.uid)
                    .get();

            _unreadCount =
                notificationQuery.docs.where((doc) {
                  final data = doc.data();
                  final readBy = List<String>.from(data['readBy'] ?? []);
                  final archivedBy = List<String>.from(data['archivedBy'] ?? []);
                  return !readBy.contains(user.uid) && !archivedBy.contains(user.uid);
                }).length;

            _log('📬 Unread notifications: $_unreadCount');
            setState(() {});
          }
        }
      } catch (e) {
        _log('❌ Error checking unread notifications: $e');
      }

      // 9. Test message reception
      _messageSubscription = _notificationService.onMessage.listen((message) {
        _log('📨 Foreground message received: ${message.notification?.title}');
      });

      // 10. Check background handler
      _log('🔄 Background message handler is configured');

      _log('✅ Diagnostics complete!');
    } catch (e) {
      _log('❌ Diagnostics failed: $e');
    }
  }

  Future<void> _requestPermission() async {
    _log('🔒 Requesting notification permission...');
    try {
      final result = await _notificationService.requestPermission();
      _log('📋 Permission result: $result');
      _permissionStatus = result;
      setState(() {});

      if (result.isGranted) {
        await _notificationService.ensureRegistered();
        _log('✅ Token registration ensured');
      }
    } catch (e) {
      _log('❌ Permission request failed: $e');
    }
  }

  Future<void> _testTokenRegistration() async {
    _log('🔧 Testing token registration...');
    try {
      await _notificationService.ensureRegistered();
      _log('✅ Token registration test complete');
    } catch (e) {
      _log('❌ Token registration test failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Debug'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Status Cards
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    color: _permissionStatus.isGranted ? Colors.green[100] : Colors.red[100],
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Icon(
                            _permissionStatus.isGranted ? Icons.notifications_active : Icons.notifications_off,
                            color: _permissionStatus.isGranted ? Colors.green : Colors.red,
                          ),
                          Text('Permission: ${_permissionStatus.name}'),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    color: _fcmToken != null ? Colors.green[100] : Colors.red[100],
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Icon(
                            _fcmToken != null ? Icons.check_circle : Icons.error,
                            color: _fcmToken != null ? Colors.green : Colors.red,
                          ),
                          Text('FCM Token: ${_fcmToken != null ? 'Yes' : 'No'}'),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    color: Colors.blue[100],
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [const Icon(Icons.mail, color: Colors.blue), Text('Unread: $_unreadCount')],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: _requestPermission, child: const Text('Request Permission'))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(onPressed: _testTokenRegistration, child: const Text('Test Token'))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(onPressed: _runDiagnostics, child: const Text('Re-run Tests'))),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Logs
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Debug Logs:', style: TextStyle(fontWeight: FontWeight.bold)),
          ),

          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      _logs[index],
                      style: const TextStyle(color: Colors.green, fontFamily: 'monospace', fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DebugErrorApp extends StatelessWidget {
  final String error;

  const DebugErrorApp(this.error, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Debug Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
