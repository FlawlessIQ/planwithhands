import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class WebOptimizedFirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Web-specific cache to reduce repeated queries
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Optimized query limits for web
  static const int _webQueryLimit = kIsWeb ? 50 : 100;
  static const int _webRealtimeLimit = kIsWeb ? 20 : 50;

  /// Get cached data or fetch from Firestore with web optimizations
  static Future<List<QueryDocumentSnapshot>> getOptimizedCollection({
    required String collection,
    String? organizationId,
    List<WhereClause>? where,
    String? orderBy,
    bool descending = false,
    int? limit,
    bool useCache = true,
    Source source = Source.serverAndCache,
  }) async {
    // Create cache key
    final cacheKey = _createCacheKey(collection, organizationId, where, orderBy, limit);
    
    // Check cache first (only on web for performance)
    if (kIsWeb && useCache && _cache.containsKey(cacheKey)) {
      final cacheTime = _cacheTimestamps[cacheKey];
      if (cacheTime != null && DateTime.now().difference(cacheTime) < _cacheExpiry) {
        return _cache[cacheKey] as List<QueryDocumentSnapshot>;
      }
    }

    // Build query with web optimizations
    Query<Map<String, dynamic>> query = organizationId != null 
        ? _firestore.collection('organizations').doc(organizationId).collection(collection)
        : _firestore.collection(collection);
    
    // Apply where clauses
    if (where != null) {
      for (final clause in where) {
        query = query.where(clause.field, isEqualTo: clause.value);
      }
    }
    
    // Apply ordering
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }
    
    // Apply web-optimized limits
    final effectiveLimit = limit ?? _webQueryLimit;
    query = query.limit(effectiveLimit);

    try {
      // Use cache-first strategy on web
      final snapshot = await query.get(GetOptions(
        source: kIsWeb ? Source.cache : source,
      ));
      
      // If cache miss on web, fetch from server
      if (kIsWeb && snapshot.docs.isEmpty && source != Source.server) {
        final serverSnapshot = await query.get(GetOptions(source: Source.server));
        _updateCache(cacheKey, serverSnapshot.docs);
        return serverSnapshot.docs;
      }
      
      _updateCache(cacheKey, snapshot.docs);
      return snapshot.docs;
    } catch (e) {
      // Fallback to server on error
      final snapshot = await query.get(GetOptions(source: Source.server));
      _updateCache(cacheKey, snapshot.docs);
      return snapshot.docs;
    }
  }

  /// Get optimized real-time stream with reduced frequency for web
  static Stream<List<QueryDocumentSnapshot>> getOptimizedStream({
    required String collection,
    String? organizationId,
    List<WhereClause>? where,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = organizationId != null 
        ? _firestore.collection('organizations').doc(organizationId).collection(collection)
        : _firestore.collection(collection);
    
    if (where != null) {
      for (final clause in where) {
        query = query.where(clause.field, isEqualTo: clause.value);
      }
    }
    
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }
    
    // Use smaller limits for real-time queries on web
    final effectiveLimit = limit ?? _webRealtimeLimit;
    query = query.limit(effectiveLimit);

    return query.snapshots().map((snapshot) => snapshot.docs);
  }

  /// Batch write optimized for web
  static Future<void> performBatchWrite(List<BatchOperation> operations) async {
    final batch = _firestore.batch();
    
    // Web browsers have lower memory limits, so use smaller batch sizes
    const webBatchLimit = kIsWeb ? 250 : 500;
    
    for (int i = 0; i < operations.length; i += webBatchLimit) {
      final batchOps = operations.skip(i).take(webBatchLimit);
      
      for (final operation in batchOps) {
        switch (operation.type) {
          case BatchOperationType.set:
            batch.set(operation.reference, operation.data!);
            break;
          case BatchOperationType.update:
            batch.update(operation.reference, operation.data!);
            break;
          case BatchOperationType.delete:
            batch.delete(operation.reference);
            break;
        }
      }
      
      await batch.commit();
      
      // Add small delay between batches on web to prevent overwhelming the browser
      if (kIsWeb && i + webBatchLimit < operations.length) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  /// Clear cache (useful for logout or data refresh)
  static void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  /// Update cache with new data
  static void _updateCache(String key, List<QueryDocumentSnapshot> docs) {
    if (kIsWeb) {
      _cache[key] = docs;
      _cacheTimestamps[key] = DateTime.now();
      
      // Clean old cache entries to prevent memory leaks
      _cleanOldCacheEntries();
    }
  }

  /// Clean old cache entries to prevent memory issues on web
  static void _cleanOldCacheEntries() {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    _cacheTimestamps.forEach((key, timestamp) {
      if (now.difference(timestamp) > _cacheExpiry) {
        keysToRemove.add(key);
      }
    });
    
    for (final key in keysToRemove) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  /// Create cache key from query parameters
  static String _createCacheKey(
    String collection,
    String? organizationId,
    List<WhereClause>? where,
    String? orderBy,
    int? limit,
  ) {
    final parts = <String>[
      collection,
      organizationId ?? 'null',
      where?.map((w) => '${w.field}:${w.value}').join(',') ?? 'null',
      orderBy ?? 'null',
      limit?.toString() ?? 'null',
    ];
    return parts.join('|');
  }
}

class WhereClause {
  final String field;
  final dynamic value;
  
  WhereClause(this.field, this.value);
}

class BatchOperation {
  final BatchOperationType type;
  final DocumentReference reference;
  final Map<String, dynamic>? data;
  
  BatchOperation(this.type, this.reference, [this.data]);
}

enum BatchOperationType { set, update, delete }