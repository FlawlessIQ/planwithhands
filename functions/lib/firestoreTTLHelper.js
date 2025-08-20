"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.FirestoreTTLHelper = void 0;
const admin = __importStar(require("firebase-admin"));
/**
 * Firestore TTL (Time-To-Live) utility helper for Cloud Functions TypeScript
 * Automatically manages expiresAt fields for collections with TTL policies
 */
class FirestoreTTLHelper {
    /**
     * Get TTL expiration timestamp for a given collection
     */
    static getExpiresAtForCollection(collectionName) {
        const ttlDays = this.collectionTTLDays[collectionName];
        if (ttlDays == null) {
            // No TTL policy for this collection
            return null;
        }
        return admin.firestore.Timestamp.fromDate(new Date(Date.now() + ttlDays * 24 * 60 * 60 * 1000));
    }
    /**
     * Add expiresAt field to document data if the collection requires TTL
     * Does not overwrite existing expiresAt values
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
     */
    static getCollectionNameFromPath(path) {
        const segments = path.split('/');
        if (segments.length < 2)
            return null;
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
    static async setWithTTL(docRef, data, options) {
        const collectionName = this.getCollectionNameFromPath(docRef.path);
        if (collectionName) {
            const dataWithTTL = this.addExpiresAtToData(collectionName, data);
            return options ? await docRef.set(dataWithTTL, options) : await docRef.set(dataWithTTL);
        }
        else {
            return options ? await docRef.set(data, options) : await docRef.set(data);
        }
    }
    /**
     * Enhanced add method that automatically adds expiresAt for TTL collections
     */
    static async addWithTTL(collectionRef, data) {
        const collectionName = this.getCollectionNameFromPath(collectionRef.path);
        if (collectionName) {
            const dataWithTTL = this.addExpiresAtToData(collectionName, data);
            return await collectionRef.add(dataWithTTL);
        }
        else {
            return await collectionRef.add(data);
        }
    }
    /**
     * Enhanced batch set method that automatically adds expiresAt for TTL collections
     */
    static batchSetWithTTL(batch, docRef, data, options) {
        const collectionName = this.getCollectionNameFromPath(docRef.path);
        if (collectionName) {
            const dataWithTTL = this.addExpiresAtToData(collectionName, data);
            if (options) {
                batch.set(docRef, dataWithTTL, options);
            }
            else {
                batch.set(docRef, dataWithTTL);
            }
        }
        else {
            if (options) {
                batch.set(docRef, data, options);
            }
            else {
                batch.set(docRef, data);
            }
        }
    }
    /**
     * Enhanced transaction set method that automatically adds expiresAt for TTL collections
     */
    static transactionSetWithTTL(transaction, docRef, data) {
        const collectionName = this.getCollectionNameFromPath(docRef.path);
        if (collectionName) {
            const dataWithTTL = this.addExpiresAtToData(collectionName, data);
            transaction.set(docRef, dataWithTTL);
        }
        else {
            transaction.set(docRef, data);
        }
    }
    /**
     * Check if a collection requires TTL
     */
    static requiresTTL(collectionName) {
        return this.collectionTTLDays.hasOwnProperty(collectionName);
    }
    /**
     * Get TTL days for a collection
     */
    static getTTLDaysForCollection(collectionName) {
        return this.collectionTTLDays[collectionName] || null;
    }
    /**
     * Get all TTL-enabled collections
     */
    static getAllTTLCollections() {
        return Object.keys(this.collectionTTLDays);
    }
    /**
     * Create a Timestamp for a specific TTL duration
     */
    static createTTLTimestamp(days) {
        return admin.firestore.Timestamp.fromDate(new Date(Date.now() + days * 24 * 60 * 60 * 1000));
    }
}
exports.FirestoreTTLHelper = FirestoreTTLHelper;
/**
 * Collection names and their TTL periods in days
 */
FirestoreTTLHelper.collectionTTLDays = {
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
