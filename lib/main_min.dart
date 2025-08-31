import 'package:flutter/material.dart';

// Minimal entrypoint to isolate iOS Safari crash. No plugins, no Firebase.
void main() {
  // Add a frame callback to confirm engine starts.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _MinimalApp());
}

class _MinimalApp extends StatelessWidget {
  const _MinimalApp();
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text('Minimal App Loaded', style: TextStyle(fontSize: 24, color: Colors.black)),
        ),
      ),
    );
  }
}
