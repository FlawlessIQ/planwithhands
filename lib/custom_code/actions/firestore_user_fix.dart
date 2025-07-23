// Run this script with `flutter run lib/custom_code/actions/firestore_user_fix.dart`
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';

Future<void> main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final firestore = FirebaseFirestore.instance;
  final usersRef = firestore.collection('users');

  final users = await usersRef.get();
  for (final doc in users.docs) {
    final data = doc.data();
    final updates = <String, dynamic>{};
    final uid = doc.id;

    // Add userId if missing
    if (!data.containsKey('userId')) {
      updates['userId'] = uid;
    }
    // Rename email to userEmail if needed
    if (data.containsKey('email') && !data.containsKey('userEmail')) {
      updates['userEmail'] = data['email'];
    }
    // Rename accessLevel to userRole if needed
    if (data.containsKey('accessLevel') && !data.containsKey('userRole')) {
      updates['userRole'] = data['accessLevel'] is int ? data['accessLevel'] : 0;
    }
    // Add phoneNumber if missing
    if (!data.containsKey('phoneNumber')) {
      updates['phoneNumber'] = 0;
    }
    // Add locationIds if missing
    if (!data.containsKey('locationIds')) {
      updates['locationIds'] = <String>[];
    }
    // Add createdAt if missing
    if (!data.containsKey('createdAt')) {
      updates['createdAt'] = FieldValue.serverTimestamp();
    }
    // Add organizationId if missing
    if (!data.containsKey('organizationId')) {
      updates['organizationId'] = '';
    }
    // Add firstName/lastName if missing
    if (!data.containsKey('firstName')) {
      updates['firstName'] = '';
    }
    if (!data.containsKey('lastName')) {
      updates['lastName'] = '';
    }
    if (updates.isNotEmpty) {
      print('Updating user $uid with $updates');
      await usersRef.doc(uid).update(updates);
    } else {
      print('User $uid is already up to date.');
    }
  }
  print('Firestore user document update complete.');
}
