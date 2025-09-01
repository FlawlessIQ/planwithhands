import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/constants/firestore_names.dart';
import 'package:hands_app/firestore_actions/organization_actions.dart';
import 'package:hands_app/data/models/organization_data.dart';
import 'package:hands_app/data/models/user_data.dart';
import 'package:hands_app/state/operational_state.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/features/messaging/services/token_registration_service.dart';
import 'package:hands_app/services/push_notification_service.dart';
import 'package:hands_app/utils/location_helper.dart';
import 'package:hands_app/utils/jobtype_helper.dart';

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
    final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    return userCredential.user;
  }

  Future<UserData?> signIn(String email, String password) async {
    debugPrint('[AUTH_CONTROLLER] Attempting sign in for email: $email');
    try {
      // Sign in with email and password
      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;
      debugPrint('[AUTH_CONTROLLER] Firebase Auth sign-in successful. UID: ${user?.uid}');

      if (user == null) {
        debugPrint('[AUTH_CONTROLLER] Error: User is null after sign-in.');
        return null;
      }

      // First, fetch user data from Firestore
      final FirebaseFirestore firestore = FirestoreEnforcer.instance;
      final userId = user.uid;
      debugPrint('[AUTH_CONTROLLER] Looking up Firestore user with UID: $userId');

      DocumentSnapshot snapshot = await firestore.collection(FirestoreCollectionNames.users).doc(userId).get();

      debugPrint('[AUTH_CONTROLLER] Firestore user document exists: ${snapshot.exists}');

      if (snapshot.exists) {
        // If the document exists, update lastLogin
        try {
          await firestore.collection('users').doc(userId).update({'lastLogin': FieldValue.serverTimestamp()});
          debugPrint('[AUTH_CONTROLLER] lastLogin timestamp updated successfully.');
        } catch (e) {
          debugPrint(
            '[AUTH_CONTROLLER] Warning: failed to update lastLogin, but proceeding since user data exists. Error: $e',
          );
        }

        // Convert Firestore data into UserData object
        var data = snapshot.data() as Map<String, dynamic>;
        debugPrint('[AUTH_CONTROLLER] Firestore user data: $data');

        DateTime createdAt = (data[UserFieldNames.createdAt] as Timestamp).toDate();

        // Handle missing or differently named fields with safe fallbacks
        String userEmail =
            data[UserFieldNames.emailAddress] ??
            data['email'] ??
            data['userEmail'] ??
            user.email ??
            'no-email@placeholder.com';

        String firstName = data[UserFieldNames.firstName] ?? '';
        String lastName = data[UserFieldNames.lastName] ?? '';
        String phoneNumber = data[UserFieldNames.phoneNumber] ?? '';
        String organizationId = data[UserFieldNames.organizationId] ?? '';

        // Handle locationIds - canonicalize into a List<String>
        final locationIds = coerceToLocationIds(
          data[UserFieldNames.locationIds] ?? data['primaryLocationId'] ?? data['locationId'],
        );

        // Handle jobTypes - might be stored as jobType (single) or jobTypes (array)
        final jobTypes = coerceToJobTypes(data[UserFieldNames.jobTypes] ?? data['jobType']);

        // Construct the UserData object
        var userData = UserData(
          userId: userId, // Use Firebase Auth UID
          createdAt: createdAt,
          userRole: (data[UserFieldNames.userRole] as int?) ?? 0,
          firstName: firstName,
          lastName: lastName,
          phoneNumber: phoneNumber,
          userEmail: userEmail,
          organizationId: organizationId,
          locationIds: locationIds,
          jobTypes: jobTypes,
        );

        // If security rules depend on orgMemberships/roles maps (new schema) but they are absent, add ephemeral client-side logging & optional patch
        final needsOrgMemberships = !(data.containsKey('orgMemberships')) && organizationId.isNotEmpty;
        final needsRoles = !(data.containsKey('roles')) && organizationId.isNotEmpty;
        if (needsOrgMemberships || needsRoles) {
          debugPrint(
            '[AUTH_CONTROLLER] User doc missing new schema fields: ${needsOrgMemberships ? 'orgMemberships ' : ''}${needsRoles ? 'roles ' : ''}- applying lightweight server merge to satisfy rules.',
          );
          try {
            final Map<String, dynamic> patch = {};
            if (needsOrgMemberships) {
              patch['orgMemberships'] = [organizationId];
            }
            if (needsRoles) {
              // Map orgId -> role string derived from userRole numeric
              String roleStr;
              switch (userData.userRole) {
                case 2:
                  roleStr = 'admin';
                  break;
                case 1:
                  roleStr = 'manager';
                  break;
                default:
                  roleStr = 'member';
              }
              patch['roles'] = {organizationId: roleStr};
            }
            if (patch.isNotEmpty) {
              await firestore.collection('users').doc(userId).set(patch, SetOptions(merge: true));
              debugPrint('[AUTH_CONTROLLER] Added missing membership fields: $patch');
            }
          } catch (e) {
            debugPrint('[AUTH_CONTROLLER] Failed to patch missing membership fields: $e');
          }
        }

        debugPrint('[AUTH_CONTROLLER] UserData object created: $userData');

        // Temporarily disable daily checklist generation to isolate login issues
        // TODO: Re-enable after fixing permission issues
        // if (userData.organizationId.isNotEmpty) {
        //   await DailyChecklistService().ensureDailyChecklistsExist(userData.organizationId);
        // }

        // Set the user data in the UserState provider
        ref.read(userStateProvider.notifier).setUserData(userData);
        debugPrint('[AUTH_CONTROLLER] UserData set in UserState provider');

        // Register FCM device token (best-effort, non-blocking)
        try {
          await TokenRegistrationService.registerCurrentDevice(userId);
        } catch (e) {
          debugPrint('[AUTH_CONTROLLER] Token registration failed: $e');
        }

        // Request notification permissions (best-effort, non-blocking)
        try {
          final permissionResult = await PushNotificationService().requestPermission();
          debugPrint('[AUTH_CONTROLLER] Notification permission result: ${permissionResult.name}');
        } catch (e) {
          debugPrint('[AUTH_CONTROLLER] Notification permission request failed: $e');
        }

        log('starting data fetch timer');
        _dataFetchTimer = Timer.periodic(Duration(seconds: _fetchInterval), (Timer timer) async {
          String? orgId = userData.organizationId;
          OrganizationData? orgData = await getOrganizationById(orgId);
          if (orgData != null) {
            log('retrived organization data at org: $orgId');
            ref.read(operationalStateProvider.notifier).setOrganizationDataToState(orgData);
            log('organization data set to state');
          }
        });

        return userData;
      } else {
        debugPrint(
          '[AUTH_CONTROLLER] CRITICAL: User exists in Auth, but no document found in Firestore for UID: $userId. The user profile may not have been created correctly.',
        );
        debugPrint('[AUTH_CONTROLLER] Attempting to create a fallback user document.');

        try {
          // Create a basic user document to allow login using current timestamp
          final now = DateTime.now();
          final newUser = {
            UserFieldNames.userId: userId,
            UserFieldNames.emailAddress: user.email ?? 'no-email@placeholder.com',
            UserFieldNames.userRole: 0, // Default role
            UserFieldNames.createdAt: Timestamp.fromDate(now),
            'lastLogin': Timestamp.fromDate(now),
            'onboardingComplete': false,
            UserFieldNames.firstName: '',
            UserFieldNames.lastName: '',
            UserFieldNames.phoneNumber: '',
            UserFieldNames.organizationId: '',
            UserFieldNames.locationIds: <String>[],
            UserFieldNames.jobTypes: <String>[],
          };

          await firestore.collection('users').doc(userId).set(newUser);
          debugPrint('[AUTH_CONTROLLER] Fallback user document created for UID: $userId');

          // Create UserData object directly from the data we just saved
          var userData = UserData(
            userId: userId,
            createdAt: now,
            userRole: 0,
            userEmail: user.email ?? 'no-email@placeholder.com',
            firstName: '',
            lastName: '',
            phoneNumber: '',
            organizationId: '',
            locationIds: [],
            jobTypes: [],
          );

          ref.read(userStateProvider.notifier).setUserData(userData);
          debugPrint('[AUTH_CONTROLLER] Fallback UserData created and set in state');
          return userData;
        } catch (fallbackError) {
          debugPrint('[AUTH_CONTROLLER] FATAL: Error creating fallback user document: $fallbackError');
          return null;
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH_CONTROLLER] FirebaseAuthException signing in: $e');
      rethrow;
    } catch (e) {
      debugPrint('[AUTH_CONTROLLER] Error signing in: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (_dataFetchTimer != null) {
      _dataFetchTimer!.cancel();
    }
    // Clear user state on sign out
    ref
        .read(userStateProvider.notifier)
        .setUserData(
          UserData(
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
          ),
        );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
