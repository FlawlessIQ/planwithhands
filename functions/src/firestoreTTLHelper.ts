import * as admin from "firebase-admin";

/**
 * Firestore TTL (Time-To-Live) utility helper for Cloud Functions TypeScript
 * Automatically manages expiresAt fields for collections with TTL policies
 */
export class FirestoreTTLHelper {
  /**
   * Collection names and their TTL periods in days
   */
  private static readonly collectionTTLDays: Record<string, number> = {
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
   */
  static getExpiresAtForCollection(collectionName: string): admin.firestore.Timestamp | null {
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
   */
  static addExpiresAtToData(
    collectionName: string,
    data: FirebaseFirestore.DocumentData
  ): FirebaseFirestore.DocumentData {
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
   */
  static getCollectionNameFromPath(path: string): string | null {
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
   */
  static async setWithTTL(
    docRef: FirebaseFirestore.DocumentReference,
    data: FirebaseFirestore.DocumentData,
    options?: FirebaseFirestore.SetOptions
  ): Promise<FirebaseFirestore.WriteResult> {
    const collectionName = this.getCollectionNameFromPath(docRef.path);
    if (collectionName) {
      const dataWithTTL = this.addExpiresAtToData(collectionName, data);
      return options ? await docRef.set(dataWithTTL, options) : await docRef.set(dataWithTTL);
    } else {
      return options ? await docRef.set(data, options) : await docRef.set(data);
    }
  }

  /**
   * Enhanced add method that automatically adds expiresAt for TTL collections
   */
  static async addWithTTL(
    collectionRef: FirebaseFirestore.CollectionReference,
    data: FirebaseFirestore.DocumentData
  ): Promise<FirebaseFirestore.DocumentReference> {
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
   */
  static batchSetWithTTL(
    batch: FirebaseFirestore.WriteBatch,
    docRef: FirebaseFirestore.DocumentReference,
    data: FirebaseFirestore.DocumentData,
    options?: FirebaseFirestore.SetOptions
  ): void {
    const collectionName = this.getCollectionNameFromPath(docRef.path);
    if (collectionName) {
      const dataWithTTL = this.addExpiresAtToData(collectionName, data);
      if (options) {
        batch.set(docRef, dataWithTTL, options);
      } else {
        batch.set(docRef, dataWithTTL);
      }
    } else {
      if (options) {
        batch.set(docRef, data, options);
      } else {
        batch.set(docRef, data);
      }
    }
  }

  /**
   * Enhanced transaction set method that automatically adds expiresAt for TTL collections
   */
  static transactionSetWithTTL(
    transaction: FirebaseFirestore.Transaction,
    docRef: FirebaseFirestore.DocumentReference,
    data: FirebaseFirestore.DocumentData
  ): void {
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
   */
  static requiresTTL(collectionName: string): boolean {
    return this.collectionTTLDays.hasOwnProperty(collectionName);
  }

  /**
   * Get TTL days for a collection
   */
  static getTTLDaysForCollection(collectionName: string): number | null {
    return this.collectionTTLDays[collectionName] || null;
  }

  /**
   * Get all TTL-enabled collections
   */
  static getAllTTLCollections(): string[] {
    return Object.keys(this.collectionTTLDays);
  }

  /**
   * Create a Timestamp for a specific TTL duration
   */
  static createTTLTimestamp(days: number): admin.firestore.Timestamp {
    return admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + days * 24 * 60 * 60 * 1000)
    );
  }
}
