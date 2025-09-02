import 'package:flutter/material.dart';

// A minimal, dependency-free app to test the core Flutter web engine on mobile Safari.
void main() {
  runApp(const MinimalCanaryApp());
}

class MinimalCanaryApp extends StatelessWidget {
  const MinimalCanaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF003366), // Dark blue
        body: Center(
          child: Text(
            'Minimal App OK\nFlutter Engine is Running',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      ),
    );
  }
}
