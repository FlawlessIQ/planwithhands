import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/constants/firestore_names.dart';
import 'package:hands_app/firestore_actions/organization_actions.dart';
import 'package:hands_app/data/models/organization_data.dart';
import 'package:hands_app/data/models/user_data.dart';
import 'package:hands_app/state/operational_state.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hands_app/services/daily_checklist_service.dart';

part 'auth_controller.g.dart';

@riverpod
class AuthController extends _$AuthController {
  // this timer checks for authentication state to pull data
  // it will pull a loggin in user's data every _fetchInterval seconds
  Timer? _dataFetchTimer;
  static const _fetchInterval = 30;

  @override
  Stream<User?> build() {
    return FirebaseAuth.instance.authStateChanges();
  }

  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<User?> signUp(String email, String password) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  }

  Future<UserData?> signIn(String email, String password) async {
    log('[DEBUG] Attempting sign in for email: $email');
    try {
      // Sign in with email and password
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      if (user != null) {
        // Update lastLogin in Firestore, ignore failures
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'lastLogin': FieldValue.serverTimestamp()});
        } catch (e) {
          log('Warning: failed to update lastLogin: $e');
        }
      }
      log('[DEBUG] Firebase Auth sign-in successful. UID: \\${userCredential.user?.uid}');

      // If the sign-in is successful, fetch user data from Firestore
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final userId = userCredential.user?.uid;
      log('[DEBUG] Looking up Firestore user with UID: \\$userId');

      if (userId != null) {
        DocumentSnapshot snapshot =
            await firestore
                .collection(FirestoreCollectionNames.users)
                .doc(userId)
                .get();
        log('[DEBUG] Firestore user document exists: \\${snapshot.exists}');
        if (snapshot.exists) {
          // Convert Firestore data into UserData object
          var data = snapshot.data() as Map<String, dynamic>;
          log('[DEBUG] Firestore user data: \\$data');

          DateTime createdAt =
              (data[UserFieldNames.createdAt] as Timestamp).toDate();

          // Construct the UserData object
          var userData = UserData(
            userId: data[UserFieldNames.userId],
            createdAt: createdAt,
            userRole: (data[UserFieldNames.userRole] as int?) ?? 0,
            firstName: data[UserFieldNames.firstName],
            lastName: data[UserFieldNames.lastName],
            phoneNumber: data[UserFieldNames.phoneNumber],
            userEmail: data[UserFieldNames.emailAddress] ?? data['userEmail'] ?? data['email'],
            organizationId: data[UserFieldNames.organizationId],
            locationIds: List<String>.from(
              data[UserFieldNames.locationIds] ?? [],
            ),
            jobTypes: List<String>.from(data[UserFieldNames.jobTypes] ?? data['jobType'] ?? []),
          );

          log('[DEBUG] UserData object created: \\$userData');

          // Ensure daily checklists are created if they don't exist
          if (userData.organizationId.isNotEmpty) {
            await DailyChecklistService().ensureDailyChecklistsExist(userData.organizationId);
          }
          
          // Set the user data in the UserState provider
          ref.read(userStateProvider.notifier).setUserData(userData);
          log('[DEBUG] UserData set in UserState provider');
          
          log('starting data fetch timer');
          _dataFetchTimer = Timer.periodic(Duration(seconds: _fetchInterval), (
            Timer timer,
          ) async {
            String? orgId = userData.organizationId; // Use the organizationId from the user data
            OrganizationData? orgData = await getOrganizationById(orgId);
            if (orgData != null) {
              log('retrived organization data at org: $orgId');
              ref
                  .read(operationalStateProvider.notifier)
                  .setOrganizationDataToState(orgData);
              log('organization data set to state');
            }
          });

          return userData;
        } else {
          log('User data not found in Firestore');
          return null;
        }
      } else {
        log('No user is logged in');
        return null;
      }
    } on FirebaseAuthException catch (e) {
      log('FirebaseAuthException signing in: $e');
      rethrow;
    } catch (e) {
      log('Error signing in: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (_dataFetchTimer != null) {
      _dataFetchTimer!.cancel();
    }
    // Clear user state on sign out
    ref.read(userStateProvider.notifier).setUserData(UserData(
      userId: '',
      createdAt: DateTime.now(),
      userRole: 0,
      firstName: '',
      lastName: '',
      phoneNumber: '',
      userEmail: '',
      organizationId: '',
      locationIds: [],
      jobTypes: [],
    ));
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
