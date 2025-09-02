import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hands_app/firebase_options.dart';

// A minimal app to test Firebase initialization.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String message = 'Firebase Init OK';
  Color backgroundColor = const Color(0xFF2E7D32); // Green

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    message = 'Firebase Init FAILED:\n$e';
    backgroundColor = const Color(0xFFC62828); // Red
  }

  runApp(MinimalFirebaseCanaryApp(message: message, backgroundColor: backgroundColor));
}

class MinimalFirebaseCanaryApp extends StatelessWidget {
  const MinimalFirebaseCanaryApp({super.key, required this.message, required this.backgroundColor});

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
