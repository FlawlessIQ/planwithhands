const admin = require("firebase-admin");

/**
 * Firestore TTL (Time-To-Live) utility helper for Cloud Functions
 * Automatically manages expiresAt fields for collections with TTL policies
 */
class FirestoreTTLHelper {
  /**
   * Collection names and their TTL periods in days
   */
  static collectionTTLDays = {
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

  /**
   * Get TTL expiration timestamp for a given collection
   * @param {string} collectionName - Name of the collection
   * @returns {admin.firestore.Timestamp|null} - TTL timestamp or null if no TTL policy
   */
  static getExpiresAtForCollection(collectionName) {
    const ttlDays = this.collectionTTLDays[collectionName];
    if (ttlDays == null) {
      // No TTL policy for this collection
      return null;
    }
    
    return admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + ttlDays * 24 * 60 * 60 * 1000)
    );
  }

  /**
   * Add expiresAt field to document data if the collection requires TTL
   * Does not overwrite existing expiresAt values
   * @param {string} collectionName - Name of the collection
   * @param {Object} data - Document data
   * @returns {Object} - Document data with expiresAt if applicable
   */
  static addExpiresAtToData(collectionName, data) {
    // Check if data already has expiresAt to avoid overwriting
    if (data.hasOwnProperty('expiresAt')) {
      return data;
    }

    const expiresAt = this.getExpiresAtForCollection(collectionName);
    if (expiresAt !== null) {
      return {
        ...data,
        expiresAt: expiresAt,
      };
    }

    return data;
  }

  /**
   * Helper method to determine collection name from a document reference path
   * Handles nested subcollections by extracting the immediate parent collection
   * @param {string} path - Document reference path
   * @returns {string|null} - Collection name or null
   */
  static getCollectionNameFromPath(path) {
    const segments = path.split('/');
    if (segments.length < 2) return null;
    
    // For paths like "organizations/orgId/locations/locId/daily_checklists/checklistId"
    // We want "daily_checklists"
    // For subcollection paths like "organizations/orgId/locations/locId/daily_checklists/checklistId/tasks/taskId"
    // We want "tasks"
    
    // Find the last collection segment (odd indices in path segments)
    for (let i = segments.length - 2; i >= 0; i -= 2) {
      const collectionName = segments[i];
      if (this.collectionTTLDays.hasOwnProperty(collectionName)) {
        return collectionName;
      }
    }
    
    return null;
  }

  /**
   * Enhanced set method that automatically adds expiresAt for TTL collections
   * @param {admin.firestore.DocumentReference} docRef - Document reference
   * @param {Object} data - Document data
   * @param {Object} options - Set options (merge, etc.)
   * @returns {Promise<admin.firestore.WriteResult>}
   */
  static async setWithTTL(docRef, data, options = {}) {
    const collectionName = this.getCollectionNameFromPath(docRef.path);
    if (collectionName) {
      const dataWithTTL = this.addExpiresAtToData(collectionName, data);
      return await docRef.set(dataWithTTL, options);
    } else {
      return await docRef.set(data, options);
    }
  }

  /**
   * Enhanced add method that automatically adds expiresAt for TTL collections
   * @param {admin.firestore.CollectionReference} collectionRef - Collection reference
   * @param {Object} data - Document data
   * @returns {Promise<admin.firestore.DocumentReference>}
   */
  static async addWithTTL(collectionRef, data) {
    const collectionName = this.getCollectionNameFromPath(collectionRef.path);
    if (collectionName) {
      const dataWithTTL = this.addExpiresAtToData(collectionName, data);
      return await collectionRef.add(dataWithTTL);
    } else {
      return await collectionRef.add(data);
    }
  }

  /**
   * Enhanced batch set method that automatically adds expiresAt for TTL collections
   * @param {admin.firestore.WriteBatch} batch - Write batch
   * @param {admin.firestore.DocumentReference} docRef - Document reference
   * @param {Object} data - Document data
   * @param {Object} options - Set options (merge, etc.)
   */
  static batchSetWithTTL(batch, docRef, data, options = {}) {
    const collectionName = this.getCollectionNameFromPath(docRef.path);
    if (collectionName) {
      const dataWithTTL = this.addExpiresAtToData(collectionName, data);
      batch.set(docRef, dataWithTTL, options);
    } else {
      batch.set(docRef, data, options);
    }
  }

  /**
   * Enhanced transaction set method that automatically adds expiresAt for TTL collections
   * @param {admin.firestore.Transaction} transaction - Transaction object
   * @param {admin.firestore.DocumentReference} docRef - Document reference
   * @param {Object} data - Document data
   */
  static transactionSetWithTTL(transaction, docRef, data) {
    const collectionName = this.getCollectionNameFromPath(docRef.path);
    if (collectionName) {
      const dataWithTTL = this.addExpiresAtToData(collectionName, data);
      transaction.set(docRef, dataWithTTL);
    } else {
      transaction.set(docRef, data);
    }
  }

  /**
   * Check if a collection requires TTL
   * @param {string} collectionName - Name of the collection
   * @returns {boolean}
   */
  static requiresTTL(collectionName) {
    return this.collectionTTLDays.hasOwnProperty(collectionName);
  }

  /**
   * Get TTL days for a collection
   * @param {string} collectionName - Name of the collection
   * @returns {number|null}
   */
  static getTTLDaysForCollection(collectionName) {
    return this.collectionTTLDays[collectionName] || null;
  }

  /**
   * Get all TTL-enabled collections
   * @returns {string[]}
   */
  static getAllTTLCollections() {
    return Object.keys(this.collectionTTLDays);
  }

  /**
   * Create a Timestamp for a specific TTL duration
   * @param {number} days - Number of days
   * @returns {admin.firestore.Timestamp}
   */
  static createTTLTimestamp(days) {
    return admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + days * 24 * 60 * 60 * 1000)
    );
  }
}

module.exports = FirestoreTTLHelper;