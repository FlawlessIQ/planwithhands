import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:intl/intl.dart';

/// Centralized service to manage shift assignments and volunteer tracking
/// This service ensures consistency between volunteers array and volunteerJoins map
class ShiftAssignmentService {
  static final ShiftAssignmentService _instance = ShiftAssignmentService._internal();
  factory ShiftAssignmentService() => _instance;
  ShiftAssignmentService._internal();

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// Check if user is assigned to a shift for today
  /// This checks both volunteers array and volunteerJoins map for consistency
  Future<bool> isUserAssignedToShift({
    required String organizationId,
    required String shiftId,
    required String userId,
    DateTime? targetDate,
  }) async {
    try {
      final dateString = _dateFormat.format(targetDate ?? DateTime.now());

      final shiftDoc =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(organizationId)
              .collection('shifts')
              .doc(shiftId)
              .get();

      if (!shiftDoc.exists) return false;

      final data = shiftDoc.data()!;

      // Check volunteers array
      final volunteers = List<String>.from(data['volunteers'] ?? []);
      final inVolunteersArray = volunteers.contains(userId);

      // Check volunteerJoins map for today
      final volunteerJoins = Map<String, dynamic>.from(data['volunteerJoins'] ?? {});
      final joinedToday = volunteerJoins[userId] == dateString;

      logger.d('[ShiftAssignment] User $userId assignment check for shift $shiftId:');
      logger.d('[ShiftAssignment] - In volunteers array: $inVolunteersArray');
      logger.d('[ShiftAssignment] - Joined today ($dateString): $joinedToday');

      // For consistency, both should be true for an active assignment
      return inVolunteersArray && joinedToday;
    } catch (e) {
      logger.e('[ShiftAssignment] Error checking user assignment: $e');
      return false;
    }
  }

  /// Join a shift as volunteer - ensures both tracking systems are updated
  Future<bool> joinShift({
    required String organizationId,
    required String shiftId,
    required String userId,
    DateTime? targetDate,
    String? joinLocationId, // Keep for API compatibility but don't use for now
  }) async {
    try {
      final dateString = _dateFormat.format(targetDate ?? DateTime.now());

      // Check if already assigned to avoid duplicate operations
      final alreadyAssigned = await isUserAssignedToShift(
        organizationId: organizationId,
        shiftId: shiftId,
        userId: userId,
        targetDate: targetDate,
      );

      if (alreadyAssigned) {
        logger.d('[ShiftAssignment] User $userId already assigned to shift $shiftId');
        return false; // Already joined
      }

      // Keep simple string for volunteerJoins and store location separately for filtering
      final updates = <String, dynamic>{
        'volunteers': FieldValue.arrayUnion([userId]),
        'volunteerJoins.$userId': dateString,
      };

      if (joinLocationId != null && joinLocationId.isNotEmpty) {
        updates['volunteerJoinLocations.$userId'] = joinLocationId;
      }

      // Use print instead of logger for guaranteed console output
      print('[ShiftAssignment] Attempting update for join: $updates (org=$organizationId shift=$shiftId user=$userId)');

      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('shifts')
          .doc(shiftId)
          .update(updates);

      logger.d('[ShiftAssignment] Successfully joined user $userId to shift $shiftId for $dateString');
      return true;
    } catch (e) {
      // Log full error and rethrow so callers can see the stacktrace in logs
      // (useful when debugging permission-denied or emulator vs prod differences).
      print('[ShiftAssignment] Error joining shift: $e');
      logger.e('[ShiftAssignment] Error joining shift: $e', e);
      // Include stacktrace in console for quick local debugging
      try {
        // ignore: avoid_print
        print('ShiftAssignment.joinShift stack:');
        // ignore: avoid_print
        print(StackTrace.current);
      } catch (_) {}
      rethrow;
    }
  }

  /// Leave a shift - removes from both tracking systems
  Future<bool> leaveShift({required String organizationId, required String shiftId, required String userId}) async {
    try {
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('shifts')
          .doc(shiftId)
          .update({
            'volunteers': FieldValue.arrayRemove([userId]),
            'volunteerJoins.$userId': FieldValue.delete(),
          });

      logger.d('[ShiftAssignment] Successfully removed user $userId from shift $shiftId');
      return true;
    } catch (e) {
      logger.e('[ShiftAssignment] Error leaving shift: $e');
      return false;
    }
  }

  /// Get all shifts assigned to user for a specific date
  /// Returns only shifts where both volunteers array and volunteerJoins are consistent
  Future<List<ShiftData>> getAssignedShifts({
    required String organizationId,
    required String userId,
    DateTime? targetDate,
    String? selectedLocationId,
  }) async {
    try {
      final dateString = _dateFormat.format(targetDate ?? DateTime.now());

      final shiftsQuery =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(organizationId)
              .collection('shifts')
              .where('volunteers', arrayContains: userId)
              .get();

      final List<ShiftData> assignedShifts = [];

      for (final doc in shiftsQuery.docs) {
        try {
          final data = doc.data();

          // Verify consistent assignment for today
          final volunteerJoins = Map<String, dynamic>.from(data['volunteerJoins'] ?? {});
          final joinedToday = volunteerJoins[userId] == dateString;

          if (joinedToday) {
            final shift = ShiftData.fromJson(data).copyWith(shiftId: doc.id);
            // If a specific location is selected, only include shifts configured for that location
            if (selectedLocationId != null && selectedLocationId.isNotEmpty) {
              final joinLocs = Map<String, dynamic>.from(data['volunteerJoinLocations'] ?? {});
              final String? userJoinLoc = (joinLocs[userId] as String?)?.trim();
              if (userJoinLoc != null && userJoinLoc.isNotEmpty) {
                if (userJoinLoc != selectedLocationId) {
                  logger.d(
                    '[ShiftAssignment] Skipping assigned shift ${shift.shiftName} - joined at $userJoinLoc, viewing $selectedLocationId',
                  );
                  continue;
                }
              }
              final dynamic rawLocs = data['locationIds'];
              final List<String> locs =
                  rawLocs is List
                      ? rawLocs.map((e) => e.toString()).toList()
                      : rawLocs is String && rawLocs.isNotEmpty
                      ? [rawLocs]
                      : const [];
              if (!locs.contains(selectedLocationId)) {
                logger.d(
                  '[ShiftAssignment] Skipping assigned shift ${shift.shiftName} - not configured for selected location $selectedLocationId (has: $locs)',
                );
                continue;
              }
            }
            assignedShifts.add(shift);
            logger.d('[ShiftAssignment] Found assigned shift: ${shift.shiftName}');
          } else {
            logger.d(
              '[ShiftAssignment] Skipping shift ${doc.id} - not joined today (marker: ${volunteerJoins[userId]})',
            );
          }
        } catch (e) {
          logger.e('[ShiftAssignment] Error parsing shift ${doc.id}: $e');
        }
      }

      logger.d('[ShiftAssignment] Found ${assignedShifts.length} assigned shifts for user $userId on $dateString');
      return assignedShifts;
    } catch (e) {
      logger.e('[ShiftAssignment] Error getting assigned shifts: $e');
      return [];
    }
  }

  /// Clean up expired volunteer joins (run during daily reset)
  /// Removes volunteerJoins entries that are older than today
  Future<void> cleanupExpiredVolunteerJoins({required String organizationId, DateTime? currentDate}) async {
    try {
      final todayString = _dateFormat.format(currentDate ?? DateTime.now());

      final shiftsQuery =
          await FirestoreEnforcer.instance.collection('organizations').doc(organizationId).collection('shifts').get();

      final batch = FirestoreEnforcer.instance.batch();
      int cleanedCount = 0;

      for (final doc in shiftsQuery.docs) {
        final data = doc.data();
        final volunteerJoins = Map<String, dynamic>.from(data['volunteerJoins'] ?? {});
        final volunteerJoinLocations = Map<String, dynamic>.from(data['volunteerJoinLocations'] ?? {});

        if (volunteerJoins.isEmpty) continue;

        final Map<String, dynamic> updatesToRemove = {};

        for (final entry in volunteerJoins.entries) {
          final userId = entry.key;
          final joinDate = entry.value?.toString() ?? '';

          // Remove entries that are not for today
          if (joinDate != todayString) {
            updatesToRemove['volunteerJoins.$userId'] = FieldValue.delete();
            if (volunteerJoinLocations.containsKey(userId)) {
              updatesToRemove['volunteerJoinLocations.$userId'] = FieldValue.delete();
            }

            // Also remove from volunteers array if they're not joined today
            final volunteers = List<String>.from(data['volunteers'] ?? []);
            if (volunteers.contains(userId)) {
              updatesToRemove['volunteers'] = FieldValue.arrayRemove([userId]);
            }

            cleanedCount++;
          }
        }

        if (updatesToRemove.isNotEmpty) {
          batch.update(doc.reference, updatesToRemove);
        }
      }

      if (cleanedCount > 0) {
        await batch.commit();
        logger.d('[ShiftAssignment] Cleaned up $cleanedCount expired volunteer assignments');
      }
    } catch (e) {
      logger.e('[ShiftAssignment] Error during cleanup: $e');
    }
  }

  /// Repair inconsistent shift assignments
  /// Ensures volunteers array and volunteerJoins map are in sync
  Future<void> repairShiftAssignmentConsistency({required String organizationId, DateTime? targetDate}) async {
    try {
      final dateString = _dateFormat.format(targetDate ?? DateTime.now());

      final shiftsQuery =
          await FirestoreEnforcer.instance.collection('organizations').doc(organizationId).collection('shifts').get();

      final batch = FirestoreEnforcer.instance.batch();
      int repairedCount = 0;

      for (final doc in shiftsQuery.docs) {
        final data = doc.data();
        final volunteers = Set<String>.from(data['volunteers'] ?? []);
        final volunteerJoins = Map<String, dynamic>.from(data['volunteerJoins'] ?? {});
        final volunteerJoinLocations = Map<String, dynamic>.from(data['volunteerJoinLocations'] ?? {});

        bool needsUpdate = false;
        final Map<String, dynamic> updates = {};

        // Remove users from volunteers array if they haven't joined today
        final Set<String> validVolunteers = {};
        for (final userId in volunteers) {
          if (volunteerJoins[userId] == dateString) {
            validVolunteers.add(userId);
          } else {
            needsUpdate = true;
          }
        }

        // Add users to volunteers array if they joined today but aren't in array
        for (final entry in volunteerJoins.entries) {
          if (entry.value == dateString && !volunteers.contains(entry.key)) {
            validVolunteers.add(entry.key);
            needsUpdate = true;
          }
        }

        // Remove join-location entries for users not joined today
        for (final entry in volunteerJoinLocations.entries) {
          final userId = entry.key;
          if (volunteerJoins[userId] != dateString) {
            updates['volunteerJoinLocations.$userId'] = FieldValue.delete();
            needsUpdate = true;
          }
        }

        if (needsUpdate) {
          updates['volunteers'] = validVolunteers.toList();

          // Clean up old volunteerJoins entries
          for (final entry in volunteerJoins.entries) {
            if (entry.value != dateString) {
              updates['volunteerJoins.${entry.key}'] = FieldValue.delete();
            }
          }

          batch.update(doc.reference, updates);
          repairedCount++;
        }
      }

      if (repairedCount > 0) {
        await batch.commit();
        logger.d('[ShiftAssignment] Repaired $repairedCount shift assignment inconsistencies');
      }
    } catch (e) {
      logger.e('[ShiftAssignment] Error during repair: $e');
    }
  }
}
