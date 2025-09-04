import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hands_app/firebase_options.dart';
import 'package:flutter/foundation.dart';

class FirebaseInitTest extends StatefulWidget {
  const FirebaseInitTest({super.key});

  @override
  State<FirebaseInitTest> createState() => _FirebaseInitTestState();
}

class _FirebaseInitTestState extends State<FirebaseInitTest> {
  bool _isInitialized = false;
  String _errorMessage = '';
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _initFirebase();
  }

  Future<void> _initFirebase() async {
    try {
      // Add debug info
      setState(() {
        _debugInfo += "Starting initialization\n";
        _debugInfo += "Is web: $kIsWeb\n";
        _debugInfo += "Firebase.apps: ${Firebase.apps.length}\n";
      });

      // If Firebase is already initialized, don't try again
      if (Firebase.apps.isNotEmpty) {
        setState(() {
          _isInitialized = true;
          _debugInfo += "Firebase already initialized\n";
        });
        return;
      }

      // Initialize Firebase
      setState(() {
        _debugInfo += "Calling Firebase.initializeApp\n";
      });

      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

      setState(() {
        _isInitialized = true;
        _debugInfo += "Firebase initialized successfully\n";
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _debugInfo += "Error: $e\n";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Init Test')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isInitialized ? Icons.check_circle : Icons.error,
                color: _isInitialized ? Colors.green : Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _isInitialized ? 'Firebase Initialized!' : 'Firebase Initialization Failed',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Error: $_errorMessage', style: TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Debug Info:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_debugInfo),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _initFirebase, child: const Text('Try Again')),
            ],
          ),
        ),
      ),
    );
  }
}
