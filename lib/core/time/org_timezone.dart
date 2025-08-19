import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;

Future<String> resolveTimezoneId({required String orgId, String? locationId}) async {
  try {
    if (locationId != null && locationId.isNotEmpty) {
      final locDoc =
          await FirebaseFirestore.instance
              .collection('organizations')
              .doc(orgId)
              .collection('locations')
              .doc(locationId)
              .get();
      if (locDoc.exists) {
        final data = locDoc.data() ?? {};
        final tzid = (data['timezoneId'] ?? data['timeZone'] ?? data['timezone']) as String?;
        if (tzid != null && tzid.isNotEmpty) return tzid;
      }
    }
    final orgDoc = await FirebaseFirestore.instance.collection('organizations').doc(orgId).get();
    if (orgDoc.exists) {
      final data = orgDoc.data() ?? {};
      final tzid = (data['timezoneId'] ?? data['timeZone'] ?? data['timezone']) as String?;
      if (tzid != null && tzid.isNotEmpty) return tzid;
    }
  } catch (e) {
    debugPrint('[TZ] Failed to resolve timezone: $e');
  }
  return 'America/New_York'; // Default fallback
}

DateTime atOrgLocal(DateTime date, int hour, int minute, {required String tzId}) {
  final loc = tz.getLocation(tzId);
  final local = tz.TZDateTime(loc, date.year, date.month, date.day, hour, minute);
  return local;
}
