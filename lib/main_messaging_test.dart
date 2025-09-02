import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hands_app/firebase_options.dart';

// A minimal app to test Firebase Messaging initialization.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String message = '...';
  Color backgroundColor = Colors.grey;

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    message = 'Firebase Core OK. Getting Messaging Token...';
    backgroundColor = const Color(0xFFFFA000); // Amber

    if (kIsWeb) {
      // On web, you need to request permission and then get the token.
      // The VAPID key is also required for web push notifications.
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken(
        vapidKey: DefaultFirebaseOptions.web.apiKey, // A common mistake is not providing this
      );
      message = 'Firebase Messaging OK\nToken: ${token?.substring(0, 10)}...';
    } else {
      // For mobile, just getting the instance is often enough to trigger issues.
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      message = 'Firebase Messaging OK\nToken: ${token?.substring(0, 10)}...';
    }

    backgroundColor = const Color(0xFF2E7D32); // Green
  } catch (e) {
    message = 'Firebase Messaging FAILED:\n$e';
    backgroundColor = const Color(0xFFC62828); // Red
  }

  runApp(MinimalMessagingCanaryApp(message: message, backgroundColor: backgroundColor));
}

class MinimalMessagingCanaryApp extends StatelessWidget {
  const MinimalMessagingCanaryApp({super.key, required this.message, required this.backgroundColor});

  final String message;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        ),
      ),
    );
  }
}
