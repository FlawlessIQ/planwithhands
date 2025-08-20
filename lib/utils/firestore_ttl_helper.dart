import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore TTL (Time-To-Live) utility helper for automatically managing expiresAt fields
class FirestoreTTLHelper {
  /// Collection names and their TTL periods in days
  static const Map<String, int> _collectionTTLDays = {
    // 30-day retention
    'daily_checklists': 30,
    'tasks': 30,
    'notifications': 30,
    'messages': 30,
    'daily_summary_by_location': 30,
    'daily_summary_by_shift': 30,
    
    // 7-day retention for short-term items
    'invites': 7,
    'debug_logs': 7,
    'debug_checklists': 7,
    'debug_tasks': 7,
    'debug_notifications': 7,
    
    // 90-day retention for important summaries
    'daily_summary_by_organization': 90,
    'daily_summary_by_organization_location': 90,
    'daily_summary_by_organization_shift': 90,
  };

  /// Get TTL expiration timestamp for a given collection
  static Timestamp? getExpiresAtForCollection(String collectionName) {
    final ttlDays = _collectionTTLDays[collectionName];
    if (ttlDays == null) {
      // No TTL policy for this collection
      return null;
    }
    
    return Timestamp.fromDate(
      DateTime.now().add(Duration(days: ttlDays)),
    );
  }

  /// Add expiresAt field to document data if the collection requires TTL
  /// Does not overwrite existing expiresAt values
  static Map<String, dynamic> addExpiresAtToData(
    String collectionName,
    Map<String, dynamic> data,
  ) {
    // Check if data already has expiresAt to avoid overwriting
    if (data.containsKey('expiresAt')) {
      return data;
    }

    final expiresAt = getExpiresAtForCollection(collectionName);
    if (expiresAt != null) {
      return {
        ...data,
        'expiresAt': expiresAt,
      };
    }

    return data;
  }

  /// Helper method to determine collection name from a document reference path
  /// Handles nested subcollections by extracting the immediate parent collection
  static String? getCollectionNameFromPath(String path) {
    final segments = path.split('/');
    if (segments.length < 2) return null;
    
    // For paths like "organizations/orgId/locations/locId/daily_checklists/checklistId"
    // We want "daily_checklists"
    // For subcollection paths like "organizations/orgId/locations/locId/daily_checklists/checklistId/tasks/taskId"
    // We want "tasks"
    
    // Find the last collection segment (odd indices in path segments)
    for (int i = segments.length - 2; i >= 0; i -= 2) {
      final collectionName = segments[i];
      if (_collectionTTLDays.containsKey(collectionName)) {
        return collectionName;
      }
    }
    
    return null;
  }

  /// Enhanced set method that automatically adds expiresAt for TTL collections
  static Future<void> setWithTTL(
    DocumentReference docRef,
    Map<String, dynamic> data, {
    SetOptions? options,
  }) async {
    final collectionName = getCollectionNameFromPath(docRef.path);
    if (collectionName != null) {
      final dataWithTTL = addExpiresAtToData(collectionName, data);
      await docRef.set(dataWithTTL, options);
    } else {
      await docRef.set(data, options);
    }
  }

  /// Enhanced add method that automatically adds expiresAt for TTL collections
  static Future<DocumentReference> addWithTTL(
    CollectionReference collectionRef,
    Map<String, dynamic> data,
  ) async {
    final collectionName = getCollectionNameFromPath(collectionRef.path);
    if (collectionName != null) {
      final dataWithTTL = addExpiresAtToData(collectionName, data);
      return await collectionRef.add(dataWithTTL);
    } else {
      return await collectionRef.add(data);
    }
  }

  /// Enhanced batch set method that automatically adds expiresAt for TTL collections
  static void batchSetWithTTL(
    WriteBatch batch,
    DocumentReference docRef,
    Map<String, dynamic> data, {
    SetOptions? options,
  }) {
    final collectionName = getCollectionNameFromPath(docRef.path);
    if (collectionName != null) {
      final dataWithTTL = addExpiresAtToData(collectionName, data);
      batch.set(docRef, dataWithTTL, options);
    } else {
      batch.set(docRef, data, options);
    }
  }

  /// Enhanced transaction set method that automatically adds expiresAt for TTL collections
  static void transactionSetWithTTL(
    Transaction transaction,
    DocumentReference docRef,
    Map<String, dynamic> data,
  ) {
    final collectionName = getCollectionNameFromPath(docRef.path);
    if (collectionName != null) {
      final dataWithTTL = addExpiresAtToData(collectionName, data);
      transaction.set(docRef, dataWithTTL);
    } else {
      transaction.set(docRef, data);
    }
  }

  /// Check if a collection requires TTL
  static bool requiresTTL(String collectionName) {
    return _collectionTTLDays.containsKey(collectionName);
  }

  /// Get TTL days for a collection
  static int? getTTLDaysForCollection(String collectionName) {
    return _collectionTTLDays[collectionName];
  }

  /// Get all TTL-enabled collections
  static List<String> getAllTTLCollections() {
    return _collectionTTLDays.keys.toList();
  }

  /// Create a Timestamp for a specific TTL duration
  static Timestamp createTTLTimestamp(int days) {
    return Timestamp.fromDate(
      DateTime.now().add(Duration(days: days)),
    );
  }
}
