import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

/// Top-level function for handling background messages
/// Must be annotated with @pragma('vm:entry-point') for Flutter 3.3+
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  logger.d('[FCM] Background message received: ${message.messageId}');
  logger.d('[FCM] Background message data: ${message.data}');

  // Handle background message logic here if needed
  // Note: Don't show UI or navigate from here
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  // Exposed navigator key for routing from background taps
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Firebase Messaging instance
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Local notifications for Android
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Stream controllers for notification events
  final StreamController<RemoteMessage> _messageStreamController = StreamController<RemoteMessage>.broadcast();
  final StreamController<String> _tokenStreamController = StreamController<String>.broadcast();

  // Public streams
  Stream<RemoteMessage> get onMessage => _messageStreamController.stream;
  Stream<String> get onTokenRefresh => _tokenStreamController.stream;

  // Current FCM token
  String? _currentToken;
  String? get currentToken => _currentToken;

  // Initialization flag
  bool _isInitialized = false;

  /// Initialize the push notification service
  Future<void> initialize() async {
    // Web push notifications: keep disabled for now only on mobile Safari; allow desktop web attempts later.
    if (kIsWeb) {
      logger.w('[PushNotificationService] Web platform detected, skipping initialization.');
      _isInitialized = true;
      return;
    }

    if (_isInitialized) return;

    try {
      logger.d('[PushNotificationService] Initializing...');

      // Initialize local notifications for Android
      if (!kIsWeb && Platform.isAndroid) {
        await _initializeLocalNotifications();
      }

      // Configure FCM for iOS foreground presentation
      if (!kIsWeb && Platform.isIOS) {
        await _firebaseMessaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

        // Don't auto-request permissions on iOS - let the app request them contextually
        logger.d(
          '[PushNotificationService] iOS configured for notifications - permissions will be requested contextually',
        );
      }

      // Set up message handlers
      _setupMessageHandlers();

      // Set up token refresh listener
      _setupTokenRefreshListener();

      // Get initial token
      await _getInitialToken();

      _isInitialized = true;
      logger.d('[PushNotificationService] Initialization complete');
    } catch (e) {
      logger.e('[PushNotificationService] Initialization error', e);
      rethrow;
    }
  }

  /// Initialize local notifications for Android
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(initSettings, onDidReceiveNotificationResponse: _onNotificationTapped);

    // Create notification channel for Android
    if (!kIsWeb && Platform.isAndroid) {
      await _createNotificationChannel();
    }
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannel() async {
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Main notification channel for general notifications
    const generalChannel = AndroidNotificationChannel(
      'general_notifications',
      'General Notifications',
      description: 'General notifications from Hands app including messages and updates.',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    // Daily summary specific channel
    const dailySummaryChannel = AndroidNotificationChannel(
      'daily_summary',
      'Daily Summary Reports',
      description: 'Daily summary reports for managers and admins.',
      importance: Importance.defaultImportance,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    // Message notifications channel
    const messageChannel = AndroidNotificationChannel(
      'messages',
      'Chat Messages',
      description: 'Chat messages and direct communications.',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    // Create all channels
    await androidPlugin.createNotificationChannel(generalChannel);
    await androidPlugin.createNotificationChannel(dailySummaryChannel);
    await androidPlugin.createNotificationChannel(messageChannel);

    logger.d('[PushNotificationService] Created Android notification channels');
  }

  /// Set up message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      logger.d('[FCM] Foreground message received: ${message.messageId}');
      logger.d('[FCM] Message data: ${message.data}');

      _onForegroundMessage(message);

      // Emit to stream for app-level handling
      _messageStreamController.add(message);
    });

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      logger.d('[FCM] Notification opened app: ${message.messageId}');
      _onOpenedMessage(message);
    });

    // Check for initial message if app was launched from notification
    _checkInitialMessage();
  }

  /// Check if app was launched from a notification
  Future<void> _checkInitialMessage() async {
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      logger.d('[FCM] App launched from notification: ${initialMessage.messageId}');
      _onOpenedMessage(initialMessage);
    }
  }

  /// Set up token refresh listener
  void _setupTokenRefreshListener() {
    _firebaseMessaging.onTokenRefresh.listen((String token) {
      logger.d('[FCM] Token refreshed: ${token.substring(0, 20)}...');
      _currentToken = token;
      _tokenStreamController.add(token);
      // Persist refreshed token to deviceTokens collection (best-effort)
      _persistToken(token);
    });
  }

  /// Get initial FCM token
  Future<void> _getInitialToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _currentToken = token;
        logger.d('[FCM] Initial token: ${token.substring(0, 20)}...');
        _tokenStreamController.add(token);
        // Persist initial token as well
        _persistToken(token);
      }
    } catch (e) {
      debugPrint('[FCM] Error getting initial token: $e');
    }
  }

  /// Persist token to Firestore using user-specific paths to avoid top-level collection writes
  Future<void> _persistToken(String token) async {
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      if (user == null) {
        logger.w('[PushNotificationService] Cannot persist token: user not authenticated');
        return;
      }
      final userId = user.uid;
      final tokenHash = token.hashCode.abs().toString();

      // Store token in user-specific subcollection to avoid top-level deviceTokens collection
      await FirestoreEnforcer.instance.collection('users').doc(userId).collection('deviceTokens').doc(tokenHash).set({
        'fcmToken': token,
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'platform':
            kIsWeb
                ? 'web'
                : Platform.isIOS
                ? 'ios'
                : Platform.isAndroid
                ? 'android'
                : 'other',
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      }, SetOptions(merge: true));

      // Also store lastFcmToken on user doc for quick debugging
      try {
        await FirestoreEnforcer.instance.collection('users').doc(userId).set({
          'lastFcmToken': token,
          'lastFcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        logger.d('[PushNotificationService] Token persisted successfully for user $userId');
      } catch (e) {
        logger.w('[PushNotificationService] Failed to update lastFcmToken on user doc: $e');
      }
    } catch (e) {
      logger.w('[PushNotificationService] Failed to persist token: $e');
    }
  }

  /// Public helper to force token refresh & registration post-permission grant
  Future<void> ensureRegistered() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        if (token != _currentToken) {
          _currentToken = token;
          _tokenStreamController.add(token);
        }
        _persistToken(token);

        // Clean up old tokens for this user to avoid duplicates
        await _cleanupOldTokens();
      }
    } catch (e) {
      logger.e('[PushNotificationService] ensureRegistered error', e);
    }
  }

  /// Clean up old or inactive tokens for the current user
  Future<void> _cleanupOldTokens() async {
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      if (user == null) return;

      final userId = user.uid;
      final currentToken = _currentToken;
      if (currentToken == null) return;

      // Get all tokens for this user
      final tokensSnapshot =
          await FirestoreEnforcer.instance.collection('users').doc(userId).collection('deviceTokens').get();

      final batch = FirestoreEnforcer.instance.batch();
      int cleanupCount = 0;

      for (final doc in tokensSnapshot.docs) {
        final data = doc.data();
        final token = data['fcmToken'] as String?;
        final isActive = data['isActive'] as bool? ?? false;

        // Mark as inactive if it's not the current token or already inactive
        if (token != currentToken || !isActive) {
          batch.update(doc.reference, {'isActive': false});
          cleanupCount++;
        }
      }

      if (cleanupCount > 0) {
        await batch.commit();
        logger.d('[PushNotificationService] Cleaned up $cleanupCount old tokens');
      }
    } catch (e) {
      logger.w('[PushNotificationService] Failed to cleanup old tokens: $e');
    }
  }

  /// Request notification permissions (native)
  Future<NotificationPermissionResult> requestPermission() async {
    try {
      debugPrint('[PushNotificationService] Requesting notification permission...');

      // Request FCM permissions (this shows native system dialog)
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('[PushNotificationService] Permission result: ${settings.authorizationStatus}');

      // Also request permission for local notifications on Android
      if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.notification.request();
        debugPrint('[PushNotificationService] Android notification permission: $status');
      }

      // Return unified result
      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
        case AuthorizationStatus.provisional:
          return NotificationPermissionResult.granted;
        case AuthorizationStatus.denied:
          return NotificationPermissionResult.denied;
        case AuthorizationStatus.notDetermined:
          return NotificationPermissionResult.notDetermined;
      }
    } catch (e) {
      logger.e('[PushNotificationService] Error requesting permission', e);
      return NotificationPermissionResult.error;
    }
  }

  /// Check current permission status
  Future<NotificationPermissionResult> checkPermissionStatus() async {
    try {
      final settings = await _firebaseMessaging.getNotificationSettings();

      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
        case AuthorizationStatus.provisional:
          return NotificationPermissionResult.granted;
        case AuthorizationStatus.denied:
          return NotificationPermissionResult.denied;
        case AuthorizationStatus.notDetermined:
          return NotificationPermissionResult.notDetermined;
      }
    } catch (e) {
      logger.e('[PushNotificationService] Error checking permission status', e);
      return NotificationPermissionResult.error;
    }
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      logger.d('[FCM] Subscribed to topic: $topic');
    } catch (e) {
      logger.e('[FCM] Error subscribing to topic $topic', e);
      rethrow;
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      logger.d('[FCM] Unsubscribed from topic: $topic');
    } catch (e) {
      logger.e('[FCM] Error unsubscribing from topic $topic', e);
      rethrow;
    }
  }

  /// Foreground message handler -> optionally show local notification
  void _onForegroundMessage(RemoteMessage message) {
    // Only show local notification for message type when app in foreground
    if (!kIsWeb && Platform.isAndroid) {
      _showLocalNotification(message, foreground: true);
    }
    _messageStreamController.add(message);
  }

  /// Handle notification tap
  /// Local notification tap -> parse payload
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    logger.d('[PushNotificationService] Notification tapped with payload: $payload');

    if (payload.startsWith('thread:')) {
      final threadId = payload.substring('thread:'.length);
      _openThread(threadId);
    } else if (payload.startsWith('daily_summary:')) {
      final orgId = payload.substring('daily_summary:'.length);
      _openDailySummary(orgId);
    }
    // Add more payload handlers as needed
  }

  /// Handle message notification opened
  void _onOpenedMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];

    logger.d('[PushNotificationService] Message opened - type: $type, data: $data');

    switch (type) {
      case 'message':
        final threadId = data['threadId'];
        if (threadId != null) {
          _openThread(threadId);
        }
        break;
      case 'daily_summary':
        final orgId = data['orgId'];
        if (orgId != null) {
          _openDailySummary(orgId);
        }
        break;
      default:
        // Handle general notifications
        logger.d('[PushNotificationService] General notification opened');
    }
  }

  /// Navigate to thread
  void _openThread(String threadId) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      logger.w('[PushNotificationService] navigator context null; scheduling post-frame nav');
      WidgetsBinding.instance.addPostFrameCallback((_) => _openThread(threadId));
      return;
    }
    final router = GoRouter.of(ctx);
    router.push('/threads/$threadId');
  }

  /// Navigate to daily summary or dashboard
  void _openDailySummary(String orgId) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      logger.w('[PushNotificationService] navigator context null; scheduling post-frame nav');
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDailySummary(orgId));
      return;
    }
    final router = GoRouter.of(ctx);
    // Navigate to dashboard or specific daily summary page
    router.push('/dashboard');
  }

  /// Show local notification (Android)
  Future<void> _showLocalNotification(RemoteMessage message, {bool foreground = false}) async {
    final notification = message.notification;
    if (notification == null) return;

    try {
      final type = message.data['type'] ?? 'general';
      String channelId;
      String channelName;
      String channelDescription;

      // Determine appropriate channel based on notification type
      switch (type) {
        case 'message':
          channelId = 'messages';
          channelName = 'Chat Messages';
          channelDescription = 'Chat messages and direct communications.';
          break;
        case 'daily_summary':
          channelId = 'daily_summary';
          channelName = 'Daily Summary Reports';
          channelDescription = 'Daily summary reports for managers and admins.';
          break;
        default:
          channelId = 'general_notifications';
          channelName = 'General Notifications';
          channelDescription = 'General notifications from Hands app including messages and updates.';
      }

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: type == 'daily_summary' ? Importance.defaultImportance : Importance.high,
        priority: type == 'daily_summary' ? Priority.defaultPriority : Priority.high,
        icon: '@mipmap/ic_launcher',
        channelShowBadge: true,
      );

      String? payload;
      if (type == 'message' && message.data['threadId'] != null) {
        payload = 'thread:${message.data['threadId']}';
      } else if (type == 'daily_summary') {
        payload = 'daily_summary:${message.data['orgId'] ?? ''}';
      } else {
        payload = message.messageId;
      }

      await _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(android: androidDetails),
        payload: payload,
      );

      logger.d('[PushNotificationService] Local notification shown for type: $type, channel: $channelId');
    } catch (e) {
      logger.e('[PushNotificationService] Error showing local notification', e);
    }
  }

  /// Get current FCM token with enhanced logging
  Future<String?> getToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      logger.d('[PushNotificationService] Current FCM token: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      logger.e('[PushNotificationService] Error getting FCM token', e);
      return null;
    }
  }

  /// Get notification settings with detailed logging
  Future<Map<String, dynamic>> getNotificationSettings() async {
    try {
      final settings = await _firebaseMessaging.getNotificationSettings();
      final settingsMap = {
        'authorizationStatus': settings.authorizationStatus.toString(),
        'alert': settings.alert.toString(),
        'badge': settings.badge.toString(),
        'sound': settings.sound.toString(),
        'carPlay': settings.carPlay.toString(),
        'lockScreen': settings.lockScreen.toString(),
        'notificationCenter': settings.notificationCenter.toString(),
      };

      logger.d('[PushNotificationService] Notification settings: $settingsMap');
      return settingsMap;
    } catch (e) {
      logger.e('[PushNotificationService] Error getting notification settings', e);
      return {};
    }
  }

  /// Enhanced permission request with better UX and logging
  Future<NotificationPermissionResult> requestPermissionWithContext({String? context}) async {
    try {
      logger.d('[PushNotificationService] Requesting notification permission - context: ${context ?? "general"}');

      // Request FCM permissions (this shows native system dialog)
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      logger.d('[PushNotificationService] Permission result: ${settings.authorizationStatus}');

      // Also request permission for local notifications on Android
      if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.notification.request();
        logger.d('[PushNotificationService] Android notification permission: $status');
      }

      // If permission granted, ensure we register the token
      NotificationPermissionResult result;
      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
        case AuthorizationStatus.provisional:
          result = NotificationPermissionResult.granted;
          // Ensure token is registered after permission grant
          await ensureRegistered();
          logger.d('[PushNotificationService] Permission granted and token registered');
          break;
        case AuthorizationStatus.denied:
          result = NotificationPermissionResult.denied;
          logger.w('[PushNotificationService] Permission denied by user');
          break;
        case AuthorizationStatus.notDetermined:
          result = NotificationPermissionResult.notDetermined;
          logger.d('[PushNotificationService] Permission not determined');
          break;
      }

      return result;
    } catch (e) {
      logger.e('[PushNotificationService] Error requesting permission', e);
      return NotificationPermissionResult.error;
    }
  }

  /// Open app settings for permission management
  Future<void> openAppSettings() async {
    try {
      await Permission.notification.request();
      // If the above doesn't open settings, try this alternative
      if (!kIsWeb) {
        await openAppSettings();
      }
    } catch (e) {
      logger.e('[PushNotificationService] Error opening app settings', e);
    }
  }

  /// Dispose resources
  void dispose() {
    _messageStreamController.close();
    _tokenStreamController.close();
  }
}

/// Enum for notification permission results
enum NotificationPermissionResult { granted, denied, notDetermined, error }

/// Extension for user-friendly permission status messages
extension NotificationPermissionResultExtension on NotificationPermissionResult {
  String get message {
    switch (this) {
      case NotificationPermissionResult.granted:
        return 'Notifications enabled successfully';
      case NotificationPermissionResult.denied:
        return 'Notifications are disabled. You can enable them in Settings > Notifications';
      case NotificationPermissionResult.notDetermined:
        return 'Notification permission not requested yet';
      case NotificationPermissionResult.error:
        return 'Error checking notification permission';
    }
  }

  bool get isGranted => this == NotificationPermissionResult.granted;
}
