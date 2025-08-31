// Web-only Firebase safety adjustments to handle restricted environments
// (e.g., Safari private mode where IndexedDB is unavailable causing plugin null errors).
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

bool webStorageUnavailable() {
  try {
    return html.window.indexedDB == null; // Safari private mode returns null
  } catch (_) {
    return true; // If access throws, treat as unavailable
  }
}

Future<void> applyFirebaseWebSafety() async {
  try {
    final ua = html.window.navigator.userAgent.toLowerCase();
    final isSafari = ua.contains('safari') && !ua.contains('chrome') && !ua.contains('android');
    final indexedDbAvailable = html.window.indexedDB != null; // null in some restricted modes

    if (!indexedDbAvailable) {
      // Disable persistence features that rely on IndexedDB
      await FirebaseAuth.instance.setPersistence(Persistence.NONE);
      try {
        FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
      } catch (_) {}
    }

    // Additional guard: if Safari and not private but features missing, still disable persistence
    if (isSafari && !indexedDbAvailable) {
      // Already handled above; kept for clarity / future expansion
    }
  } catch (_) {
    // Swallow; never let safety adjustments crash startup
  }
}
