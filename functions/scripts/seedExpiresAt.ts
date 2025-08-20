#!/usr/bin/env node
/**
 * Firestore TTL Seeder Script
 * Ensures expiresAt field exists in target collections to enable TTL policies
 */

import * as admin from "firebase-admin";

// Initialize Firebase Admin (assumes GOOGLE_APPLICATION_CREDENTIALS is set)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

interface CollectionConfig {
  name: string;
  ttlDays: number;
  queryType: 'collection' | 'collectionGroup' | 'both';
  topLevelPaths?: string[]; // For specific top-level collections
}

interface SeedResult {
  updated: boolean;
  docPath?: string;
  ttlDays: number;
  reason?: string;
  error?: string;
}

type SeedSummary = Record<string, SeedResult>;

// Collection configurations with TTL settings
const COLLECTION_CONFIGS: CollectionConfig[] = [
  // 30-day retention
  { name: 'daily_checklists', ttlDays: 30, queryType: 'collectionGroup' },
  { name: 'tasks', ttlDays: 30, queryType: 'collectionGroup' },
  { name: 'notifications', ttlDays: 30, queryType: 'both', topLevelPaths: ['notifications'] },
  { name: 'messages', ttlDays: 30, queryType: 'collectionGroup' },
  { name: 'daily_summary_by_location', ttlDays: 30, queryType: 'collectionGroup' },
  { name: 'daily_summary_by_shift', ttlDays: 30, queryType: 'collectionGroup' },

  // 7-day retention
  { name: 'invites', ttlDays: 7, queryType: 'both', topLevelPaths: ['invites'] },
  { name: 'debug_logs', ttlDays: 7, queryType: 'collectionGroup' },
  { name: 'debug_checklists', ttlDays: 7, queryType: 'collectionGroup' },
  { name: 'debug_tasks', ttlDays: 7, queryType: 'collectionGroup' },
  { name: 'debug_notifications', ttlDays: 7, queryType: 'collectionGroup' },

  // 90-day retention
  { name: 'daily_summary_by_organization', ttlDays: 90, queryType: 'collectionGroup' },
  { name: 'daily_summary_by_organization_location', ttlDays: 90, queryType: 'collectionGroup' },
  { name: 'daily_summary_by_organization_shift', ttlDays: 90, queryType: 'collectionGroup' },
  { name: 'daily_summary_logs', ttlDays: 90, queryType: 'collectionGroup' },
];

/**
 * Parse command line arguments
 */
function parseArgs() {
  const args = process.argv.slice(2);
  const options = {
    dryRun: false,
    limit: 1,
    include: [] as string[],
  };

  for (const arg of args) {
    if (arg === '--dry-run') {
      options.dryRun = true;
    } else if (arg.startsWith('--limit=')) {
      options.limit = parseInt(arg.split('=')[1]) || 1;
    } else if (arg.startsWith('--include=')) {
      options.include = arg.split('=')[1].split(',').map(s => s.trim()).filter(Boolean);
    }
  }

  return options;
}

/**
 * Create TTL timestamp for given days
 */
function createTTLTimestamp(days: number): admin.firestore.Timestamp {
  return admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + days * 24 * 60 * 60 * 1000)
  );
}

/**
 * Seed a single document with expiresAt if it doesn't exist
 */
async function seedDocument(
  docRef: admin.firestore.DocumentReference,
  ttlDays: number,
  dryRun: boolean
): Promise<{ updated: boolean; reason?: string }> {
  try {
    const doc = await docRef.get();
    
    if (!doc.exists) {
      return { updated: false, reason: 'document does not exist' };
    }

    const data = doc.data() || {};
    
    if (data.expiresAt) {
      return { updated: false, reason: 'already has expiresAt' };
    }

    if (dryRun) {
      return { updated: true, reason: 'would add expiresAt (dry-run)' };
    }

    // Update with expiresAt field
    const expiresAt = createTTLTimestamp(ttlDays);
    await docRef.update({ expiresAt });
    
    return { updated: true };
  } catch (error) {
    throw new Error(`Failed to seed document ${docRef.path}: ${error}`);
  }
}

/**
 * Seed collection using collectionGroup query
 */
async function seedCollectionGroup(
  collectionName: string,
  ttlDays: number,
  limit: number,
  dryRun: boolean
): Promise<SeedResult> {
  try {
    const query = db.collectionGroup(collectionName).limit(limit);
    const snapshot = await query.get();

    if (snapshot.empty) {
      return {
        updated: false,
        ttlDays,
        reason: 'no documents found in collectionGroup'
      };
    }

    // Try to seed the first document
    const firstDoc = snapshot.docs[0];
    const seedResult = await seedDocument(firstDoc.ref, ttlDays, dryRun);

    return {
      updated: seedResult.updated,
      docPath: firstDoc.ref.path,
      ttlDays,
      reason: seedResult.reason
    };
  } catch (error) {
    return {
      updated: false,
      ttlDays,
      error: `CollectionGroup error: ${error}`
    };
  }
}

/**
 * Seed top-level collection
 */
async function seedTopLevelCollection(
  collectionPath: string,
  ttlDays: number,
  limit: number,
  dryRun: boolean
): Promise<SeedResult> {
  try {
    const query = db.collection(collectionPath).limit(limit);
    const snapshot = await query.get();

    if (snapshot.empty) {
      return {
        updated: false,
        ttlDays,
        reason: `no documents found in collection ${collectionPath}`
      };
    }

    // Try to seed the first document
    const firstDoc = snapshot.docs[0];
    const seedResult = await seedDocument(firstDoc.ref, ttlDays, dryRun);

    return {
      updated: seedResult.updated,
      docPath: firstDoc.ref.path,
      ttlDays,
      reason: seedResult.reason
    };
  } catch (error) {
    return {
      updated: false,
      ttlDays,
      error: `Collection error: ${error}`
    };
  }
}

/**
 * Seed a single collection configuration
 */
async function seedCollection(
  config: CollectionConfig,
  limit: number,
  dryRun: boolean
): Promise<SeedResult> {
  const { name, ttlDays, queryType, topLevelPaths } = config;

  try {
    // Try collectionGroup first if supported
    if (queryType === 'collectionGroup' || queryType === 'both') {
      const result = await seedCollectionGroup(name, ttlDays, limit, dryRun);
      if (result.updated || !result.reason?.includes('no documents found')) {
        return result;
      }
    }

    // Try top-level collections if specified
    if ((queryType === 'collection' || queryType === 'both') && topLevelPaths) {
      for (const path of topLevelPaths) {
        const result = await seedTopLevelCollection(path, ttlDays, limit, dryRun);
        if (result.updated || !result.reason?.includes('no documents found')) {
          return result;
        }
      }
    }

    return {
      updated: false,
      ttlDays,
      reason: 'no documents found in any query method'
    };
  } catch (error) {
    return {
      updated: false,
      ttlDays,
      error: String(error)
    };
  }
}

/**
 * Main seeding function
 */
async function seedExpiresAt(): Promise<void> {
  const options = parseArgs();
  console.log('🌱 Firestore TTL Seeder Script');
  console.log(`📋 Options: dryRun=${options.dryRun}, limit=${options.limit}`);
  
  if (options.include.length > 0) {
    console.log(`🔍 Including only: ${options.include.join(', ')}`);
  }

  const summary: SeedSummary = {};
  let totalUpdated = 0;

  // Filter collections if include list is provided
  const collectionsToProcess = options.include.length > 0
    ? COLLECTION_CONFIGS.filter(config => options.include.includes(config.name))
    : COLLECTION_CONFIGS;

  console.log(`\n🎯 Processing ${collectionsToProcess.length} collections...\n`);

  for (const config of collectionsToProcess) {
    try {
      console.log(`  Processing ${config.name} (${config.ttlDays}d TTL)...`);
      
      const result = await seedCollection(config, options.limit, options.dryRun);
      summary[config.name] = result;

      if (result.updated) {
        totalUpdated++;
        console.log(`    ✅ ${options.dryRun ? '[DRY-RUN] Would update' : 'Updated'}: ${result.docPath}`);
      } else {
        const status = result.error ? '❌ Error' : '⏭️  Skipped';
        const reason = result.error || result.reason;
        console.log(`    ${status}: ${reason}`);
      }
    } catch (error) {
      summary[config.name] = {
        updated: false,
        ttlDays: config.ttlDays,
        error: String(error)
      };
      console.log(`    ❌ Error: ${error}`);
    }
  }

  // Print summary
  console.log('\n📊 Summary:');
  console.log(JSON.stringify(summary, null, 2));
  
  console.log(`\n✨ Completed! ${totalUpdated} collections ${options.dryRun ? 'would be' : 'were'} seeded.`);
  
  if (options.dryRun) {
    console.log('\n💡 Run without --dry-run to apply changes.');
  } else if (totalUpdated > 0) {
    console.log('\n🔥 TTL policies can now be enabled in Firebase Console!');
    console.log('   Go to: Firestore → Data → Indexes & TTL → Create TTL policy');
    console.log('   Field name: expiresAt');
  }
}

// Run the script
if (require.main === module) {
  seedExpiresAt()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('💥 Script failed:', error);
      process.exit(1);
    });
}

export { seedExpiresAt };
