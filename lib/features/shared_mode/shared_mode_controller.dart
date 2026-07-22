import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/features/shared_mode/shared_mode_state.dart';
import 'package:hands_app/services/push_notification_service.dart';
import 'package:hands_app/services/location_selection_service.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedModeControllerProvider =
    StateNotifierProvider<SharedModeController, SharedModeState>((ref) {
      final controller = SharedModeController(ref);
      // Fire-and-forget init; controller exposes a synchronous default state.
      controller.init();
      return controller;
    });

class SharedModeController extends StateNotifier<SharedModeState> {
  static const _prefsEnabled = 'sharedMode.enabled';
  static const _prefsOwnerUserId = 'sharedMode.ownerUserId';
  static const _prefsOwnerOrgId = 'sharedMode.ownerOrgId';
  static const _prefsLocationId = 'sharedMode.locationId';

  Timer? _autoLockTimer;
  DateTime _lastActivity = DateTime.fromMillisecondsSinceEpoch(0);

  bool _userMatchesLocation({
    required Map<String, dynamic> userData,
    required String locationId,
  }) {
    final dynamic raw =
        userData['locationIds'] ??
        userData['locations'] ??
        userData['locationId'] ??
        userData['location'];
    if (raw == null) return false;

    final Iterable<dynamic> entries = (raw is Iterable) ? raw : <dynamic>[raw];

    for (final entry in entries) {
      if (entry == null) continue;

      // Typical schema: list of locationId strings.
      if (entry is String) {
        final v = entry.trim();
        if (v == locationId) return true;
        // Sometimes we store a path string (e.g. organizations/{orgId}/locations/{locationId}).
        if (v.endsWith('/$locationId') || v.contains('/locations/$locationId'))
          return true;
        continue;
      }

      // Some data uses DocumentReference values.
      if (entry is DocumentReference) {
        if (entry.id == locationId) return true;
        if (entry.path.endsWith('/$locationId') ||
            entry.path.contains('/locations/$locationId'))
          return true;
        continue;
      }

      // Defensive: sometimes a map like {id: <locationId>}.
      if (entry is Map) {
        final id = entry['id'] ?? entry['locationId'];
        if (id?.toString() == locationId) return true;
        continue;
      }

      // Last resort: try to match against a string representation.
      final s = entry.toString();
      if (s == locationId) return true;
      if (s.contains('/locations/$locationId') || s.endsWith('/$locationId'))
        return true;
    }

    return false;
  }

  SharedModeController(Ref ref) : super(const SharedModeState.disabled());

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefsEnabled) ?? false;
    if (!enabled) return;

    state = SharedModeState(
      enabled: true,
      ownerUserId: prefs.getString(_prefsOwnerUserId),
      ownerOrgId: prefs.getString(_prefsOwnerOrgId),
      locationId: prefs.getString(_prefsLocationId),
      // Always start locked on relaunch.
      activeUserId: null,
      activeUserName: null,
      activeUserEmail: null,
    );

    _startAutoLockTimer();
  }

  Future<void> enterSharedMode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No authenticated user');

    // Resolve orgId from the users doc.
    final userSnap =
        await FirestoreEnforcer.instance
            .collection('users')
            .doc(user.uid)
            .get();
    final userData = userSnap.data();
    final orgId = userData?['organizationId']?.toString();
    if (orgId == null || orgId.isEmpty)
      throw StateError('Missing organizationId');

    // Shared Mode requires the owner to have a PIN set.
    final hasPin = userData?['hasSharedModePin'] == true;
    if (!hasPin) {
      throw StateError('Shared Mode PIN not set');
    }

    final locationId = LocationSelectionService.instance.currentLocationId;
    if (locationId == null || locationId.isEmpty) {
      throw StateError('Shared Mode requires a selected location');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsEnabled, true);
    await prefs.setString(_prefsOwnerUserId, user.uid);
    await prefs.setString(_prefsOwnerOrgId, orgId);
    await prefs.setString(_prefsLocationId, locationId);

    state = SharedModeState(
      enabled: true,
      ownerUserId: user.uid,
      ownerOrgId: orgId,
      locationId: locationId,
      activeUserId: null,
      activeUserName: null,
      activeUserEmail: null,
    );

    _startAutoLockTimer();
  }

  Future<void> lock() async {
    state = state.copyWith(clearActiveUser: true);
  }

  Future<void> signOutDevice() async {
    await disableSharedMode();
    await PushNotificationService().detachCurrentDeviceFromUser(
      context: 'shared_mode_sign_out',
    );
    await FirebaseAuth.instance.signOut();
  }

  Future<void> disableSharedMode() async {
    _autoLockTimer?.cancel();
    _autoLockTimer = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsEnabled);
    await prefs.remove(_prefsOwnerUserId);
    await prefs.remove(_prefsOwnerOrgId);
    await prefs.remove(_prefsLocationId);

    state = const SharedModeState.disabled();
  }

  /// Called frequently; keep it cheap.
  void recordActivity() {
    if (!state.enabled || state.locked) return;
    _lastActivity = DateTime.now();
  }

  void _startAutoLockTimer() {
    _autoLockTimer?.cancel();
    _lastActivity = DateTime.now();

    _autoLockTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!state.enabled || state.locked) return;

      // Default inactivity window.
      const inactivity = Duration(seconds: 90);
      if (DateTime.now().difference(_lastActivity) >= inactivity) {
        // Auto-lock back to picker.
        lock();
      }
    });
  }

  Future<void> setPin({required String pin}) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'sharedModeSetPin',
    );
    await callable.call({'pin': pin});
  }

  Future<void> verifyAndActivateUser({
    required String userId,
    required String pin,
  }) async {
    final locId =
        state.locationId ?? LocationSelectionService.instance.currentLocationId;
    final orgId = state.ownerOrgId;
    if (!state.enabled ||
        locId == null ||
        locId.isEmpty ||
        orgId == null ||
        orgId.isEmpty) {
      throw StateError('Shared Mode not initialized');
    }

    final callable = FirebaseFunctions.instance.httpsCallable(
      'sharedModeVerifyPin',
    );
    final result = await callable.call({
      'targetUserId': userId,
      'pin': pin,
      'locationId': locId,
      'orgId': orgId,
    });

    final data =
        (result.data as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    if (data['ok'] != true) {
      throw StateError('Invalid PIN');
    }

    state = state.copyWith(
      activeUserId: data['userId']?.toString() ?? userId,
      activeUserName: data['displayName']?.toString() ?? 'Staff',
      activeUserEmail: data['email']?.toString(),
    );

    recordActivity();
  }

  Future<bool> verifyOwnerPinToExit({required String pin}) async {
    if (!state.enabled) return true;
    final ownerId = state.ownerUserId;
    final locId = state.locationId;
    final orgId = state.ownerOrgId;
    if (ownerId == null || locId == null || orgId == null) return false;

    final callable = FirebaseFunctions.instance.httpsCallable(
      'sharedModeVerifyPin',
    );
    final result = await callable.call({
      'targetUserId': ownerId,
      'pin': pin,
      'locationId': locId,
      'orgId': orgId,
    });
    final data =
        (result.data as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return data['ok'] == true;
  }

  /// Best-effort helper for task attribution.
  Map<String, String?> completionActor() {
    if (state.enabled && !state.locked && state.activeUserId != null) {
      return {
        'userId': state.activeUserId,
        'name': state.activeUserName,
        'email': state.activeUserEmail,
      };
    }

    final user = FirebaseAuth.instance.currentUser;
    return {
      'userId': user?.uid,
      'name': user?.displayName,
      'email': user?.email,
    };
  }

  /// Loads users for the current location.
  ///
  /// Note: Shared Mode requires the selected user to have a PIN; the UI can
  /// show users without a PIN as disabled with instructions.
  Stream<List<Map<String, dynamic>>> eligibleUsersStream() {
    final orgId = state.ownerOrgId;
    if (!state.enabled || orgId == null || orgId.isEmpty) {
      return const Stream.empty();
    }

    return FirestoreEnforcer.instance
        .collection('users')
        .where('organizationId', isEqualTo: orgId)
        .snapshots()
        .map((snap) {
          final locId = state.locationId;
          final out = <Map<String, dynamic>>[];

          for (final doc in snap.docs) {
            final data = doc.data();
            if ((data['isActive'] ?? true) == false) continue;

            bool matchesLocation = true;
            if (locId != null && locId.isNotEmpty) {
              matchesLocation = _userMatchesLocation(
                userData: data,
                locationId: locId,
              );
            }
            if (!matchesLocation) continue;

            final hasPin = data['hasSharedModePin'] == true;

            final first = (data['firstName'] ?? '').toString().trim();
            final last = (data['lastName'] ?? '').toString().trim();
            final displayName = ('$first $last').trim();

            out.add({
              'id': doc.id,
              'displayName':
                  displayName.isNotEmpty
                      ? displayName
                      : (data['name'] ?? data['emailAddress'] ?? 'User'),
              'email':
                  (data['emailAddress'] ?? data['email'] ?? data['userEmail'])
                      ?.toString(),
              'hasPin': hasPin,
            });
          }

          out.sort(
            (a, b) => a['displayName'].toString().compareTo(
              b['displayName'].toString(),
            ),
          );
          return out;
        });
  }
}
