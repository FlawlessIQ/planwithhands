import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';

/// Top-level function for handling background messages
/// Must be annotated with @pragma('vm:entry-point') for Flutter 3.3+
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message received: ${message.messageId}');
  debugPrint('[FCM] Background message data: ${message.data}');

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
    if (_isInitialized) return;

    try {
      debugPrint('[PushNotificationService] Initializing...');

      // Initialize local notifications for Android
      if (!kIsWeb && Platform.isAndroid) {
        await _initializeLocalNotifications();
      }

      // Configure FCM for iOS foreground presentation
      if (!kIsWeb && Platform.isIOS) {
        await _firebaseMessaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      }

      // Set up message handlers
      _setupMessageHandlers();

      // Set up token refresh listener
      _setupTokenRefreshListener();

      // Get initial token
      await _getInitialToken();

      _isInitialized = true;
      debugPrint('[PushNotificationService] Initialization complete');
    } catch (e) {
      debugPrint('[PushNotificationService] Initialization error: $e');
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

  /// Create Android notification channel
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications from Hands app.',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Set up message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground message received: ${message.messageId}');
      debugPrint('[FCM] Message data: ${message.data}');

      _onForegroundMessage(message);

      // Emit to stream for app-level handling
      _messageStreamController.add(message);
    });

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Notification opened app: ${message.messageId}');
      _onOpenedMessage(message);
    });

    // Check for initial message if app was launched from notification
    _checkInitialMessage();
  }

  /// Check if app was launched from a notification
  Future<void> _checkInitialMessage() async {
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] App launched from notification: ${initialMessage.messageId}');
      _onOpenedMessage(initialMessage);
    }
  }

  /// Set up token refresh listener
  void _setupTokenRefreshListener() {
    _firebaseMessaging.onTokenRefresh.listen((String token) {
      debugPrint('[FCM] Token refreshed: ${token.substring(0, 20)}...');
      _currentToken = token;
      _tokenStreamController.add(token);
    });
  }

  /// Get initial FCM token
  Future<void> _getInitialToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _currentToken = token;
        debugPrint('[FCM] Initial token: ${token.substring(0, 20)}...');
        _tokenStreamController.add(token);
      }
    } catch (e) {
      debugPrint('[FCM] Error getting initial token: $e');
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
      debugPrint('[PushNotificationService] Error requesting permission: $e');
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
      debugPrint('[PushNotificationService] Error checking permission status: $e');
      return NotificationPermissionResult.error;
    }
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('[FCM] Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('[FCM] Error subscribing to topic $topic: $e');
      rethrow;
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('[FCM] Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('[FCM] Error unsubscribing from topic $topic: $e');
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

  /// Handle notification opened (background/terminated)
  void _onOpenedMessage(RemoteMessage message) {
    _handleMessage(message, opened: true);
  }

  void _handleMessage(RemoteMessage message, {bool opened = false}) {
    final data = message.data;
    final type = data['type'];
    if (type == 'message') {
      final threadId = data['threadId'];
      if (threadId != null) {
        _openThread(threadId);
      }
    }
  }

  void _openThread(String threadId) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      debugPrint('[PushNotificationService] navigator context null; scheduling post-frame nav');
      WidgetsBinding.instance.addPostFrameCallback((_) => _openThread(threadId));
      return;
    }
    final router = GoRouter.of(ctx);
    router.push('/threads/$threadId');
  }

  /// Show local notification (Android)
  Future<void> _showLocalNotification(RemoteMessage message, {bool foreground = false}) async {
    final notification = message.notification;
    if (notification == null) return;

    try {
      final isMessage = message.data['type'] == 'message';
      final androidDetails = AndroidNotificationDetails(
        isMessage ? 'messages' : 'high_importance_channel',
        isMessage ? 'Messages' : 'High Importance Notifications',
        channelDescription:
            isMessage ? 'Message notifications' : 'This channel is used for important notifications from Hands app.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        channelShowBadge: true,
      );
      await _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(android: androidDetails),
        payload:
            isMessage && message.data['threadId'] != null ? 'thread:${message.data['threadId']}' : message.messageId,
      );
    } catch (e) {
      debugPrint('[PushNotificationService] Error showing local notification: $e');
    }
  }

  /// Handle notification tap
  /// Local notification tap -> parse payload
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.startsWith('thread:')) {
      final threadId = payload.substring('thread:'.length);
      _openThread(threadId);
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
      debugPrint('[PushNotificationService] Error opening app settings: $e');
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
