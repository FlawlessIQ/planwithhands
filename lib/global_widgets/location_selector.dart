import 'package:flutter/material.dart';
import 'package:hands_app/services/location_selection_service.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper that resolves which locations a user is allowed to access.
class AllowedLocationsResolver {
  final FirebaseFirestore _db;
  AllowedLocationsResolver(this._db);

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  streamAllowedLocations({
    required int userRole,
    required String orgId,
    required List<String>? assignedLocationIds,
    required List<DocumentReference<Map<String, dynamic>>>?
    assignedLocationRefs,
  }) {
    final locationsCol = _db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() as Map<String, dynamic>,
          toFirestore: (m, _) => m,
        );

    if (userRole == 2) {
      // Admins: all active locations in org
      return locationsCol
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((s) => s.docs);
    }

    // Staff/Managers: only assigned locations
    final ids = <String>[];
    if (assignedLocationIds != null) ids.addAll(assignedLocationIds);
    if (assignedLocationRefs != null && assignedLocationRefs.isNotEmpty) {
      ids.addAll(assignedLocationRefs.map((r) => r.id));
    }
    final uniqueIds = ids.toSet().toList();

    if (uniqueIds.isEmpty) {
      return Stream.value(<QueryDocumentSnapshot<Map<String, dynamic>>>[]);
    }

    // If within whereIn limit
    if (uniqueIds.length <= 10) {
      return locationsCol
          .where(FieldPath.documentId, whereIn: uniqueIds)
          .snapshots()
          .map((s) => s.docs);
    }

    // Chunk into multiple streams and combine manually: listen to each snapshot stream and merge
    final controllers =
        <Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>[];
    for (var i = 0; i < uniqueIds.length; i += 10) {
      final slice = uniqueIds.sublist(i, (i + 10).clamp(0, uniqueIds.length));
      controllers.add(
        locationsCol
            .where(FieldPath.documentId, whereIn: slice)
            .snapshots()
            .map((s) => s.docs),
      );
    }

    // Merge updates from all chunk streams into one stream
    final controller =
        StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>();
    final latest =
        List<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.filled(
          controllers.length,
          [],
        );
    final subs =
        <
          StreamSubscription<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
        >[];
    for (var idx = 0; idx < controllers.length; idx++) {
      final sub = controllers[idx].listen(
        (docs) {
          latest[idx] = docs;
          // combine
          final combined = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          for (final l in latest) {
            combined.addAll(l);
          }
          controller.add(combined);
        },
        onError: (e) {
          controller.addError(e);
        },
      );
      subs.add(sub);
    }

    controller.onCancel = () {
      for (final s in subs) {
        s.cancel();
      }
    };

    return controller.stream;
  }
}

/// Persist the user's selected current location to their user document and sync in-memory state.
Future<void> setCurrentLocation({
  required String uid,
  required DocumentReference<Map<String, dynamic>> locationRef,
  required String locationName,
}) async {
  await FirestoreEnforcer.instance.collection('users').doc(uid).update({
    'currentLocationRef': locationRef,
    'currentLocationId': locationRef.id,
    'currentLocationName': locationName,
    'updatedAt': FieldValue.serverTimestamp(),
  });
  // Also update global service
  try {
    await LocationSelectionService.instance.setLocationAsync(
      locationRef.id,
      locationName: locationName,
    );
  } catch (_) {}
}

/// A compact, minimal location selector widget that can be reused across dashboard pages
class LocationSelector extends StatelessWidget {
  final String? selectedLocationId;
  final List<Map<String, dynamic>> availableLocations;
  final Function(String) onLocationChanged;
  final bool isLoading;

  const LocationSelector({
    super.key,
    required this.selectedLocationId,
    required this.availableLocations,
    required this.onLocationChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Build dropdown items first
    final items =
        availableLocations
            .map(
              (location) => DropdownMenuItem<String>(
                value: location['id'] as String,
                child: Text(
                  location['name'] as String,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList();

    // Determine effective selection; ensure value exists in items to avoid exceptions
    final initialSelected =
        selectedLocationId ??
        LocationSelectionService.instance.currentLocationId;
    final effectiveSelectedId =
        items.any((it) => it.value == initialSelected) ? initialSelected : null;

    // Don't show if only one location
    if (availableLocations.length <= 1) {
      // Still update global so other pages remain consistent
      if (effectiveSelectedId == null && availableLocations.isNotEmpty) {
        // Persist first location as default asynchronously
        // ignore: discarded_futures
        LocationSelectionService.instance.setLocationAsync(
          availableLocations.first['id'] as String?,
          locationName: availableLocations.first['name'] as String?,
        );
      }
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            size: 18,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            'Location:',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                isLoading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: effectiveSelectedId,
                        isExpanded: true,
                        hint: const Text('Select location'),
                        style: Theme.of(context).textTheme.bodyMedium,
                        onChanged: (value) async {
                          if (value != null) {
                            // Update caller
                            onLocationChanged(value);
                            // Persist globally
                            final selectedLocation = availableLocations
                                .firstWhere(
                                  (location) => location['id'] == value,
                                  orElse: () => <String, dynamic>{},
                                );
                            await LocationSelectionService.instance
                                .setLocationAsync(
                                  value,
                                  locationName:
                                      selectedLocation['name'] as String?,
                                );
                          }
                        },
                        items: items,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
