import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Script to trigger daily summary for Oct 1, 2025
/// Run with: dart run trigger_daily_summary_oct1.dart
Future<void> main() async {
  print('\n╔═══════════════════════════════════════════════════════════════╗');
  print('║      Trigger Daily Summary for Oct 1, 2025                   ║');
  print('╚═══════════════════════════════════════════════════════════════╝\n');

  try {
    // Initialize Firebase
    print('⏳ Initializing Firebase...');
    await Firebase.initializeApp();

    // Check if user is authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('❌ No user is currently logged in');
      print('   Please run the app and log in as an admin first\n');
      return;
    }

    print('✅ Authenticated as: ${currentUser.email}\n');

    final orgId = '3qjYzHagWmfbnMieJ1aj';
    final targetDate = '2025-10-01';

    print('📋 Configuration:');
    print('   Organization ID: $orgId');
    print('   Target Date: $targetDate');
    print('   Email will be sent to: con.lawless@gmail.com\n');

    print('⏳ Calling triggerDailySummary Cloud Function...\n');

    // Call the function
    final callable = FirebaseFunctions.instance.httpsCallable('triggerDailySummary');

    final result = await callable.call<Map<String, dynamic>>({'orgId': orgId, 'targetDate': targetDate});

    print('✅ Function executed successfully!');
    print('📧 Email should arrive at: con.lawless@gmail.com\n');
    print('📊 Result: ${result.data}\n');
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('\nStack trace:');
    print(stackTrace);
    print('\n');
  }
}
