# Firestore TTL Seeder Script

This script ensures that at least one document in each TTL-enabled collection has an `expiresAt` field, which is required to enable TTL policies in the Firebase Console.

## Purpose

Before you can enable TTL policies in Firebase Console, Firestore needs to see at least one document with the TTL field (`expiresAt`) to understand the field structure. This script seeds that field into existing documents.

## Files

- `seedExpiresAt.ts` - TypeScript version (requires ts-node or compilation)
- `seedExpiresAt.js` - JavaScript version (ready to run with Node.js)

## Usage

### Basic Usage

```bash
# TypeScript version (requires ts-node)
npx ts-node scripts/seedExpiresAt.ts

# JavaScript version 
node scripts/seedExpiresAt.js

# Dry-run mode (see what would be changed without making changes)
node scripts/seedExpiresAt.js --dry-run
```

### Advanced Usage

```bash
# Seed only specific collections
node scripts/seedExpiresAt.js --include=daily_checklists,notifications

# Seed multiple documents per collection (for testing)
node scripts/seedExpiresAt.js --limit=5

# Combine options
node scripts/seedExpiresAt.js --dry-run --include=invites,tasks --limit=3
```

## Command Line Options

| Option | Default | Description |
|--------|---------|-------------|
| `--dry-run` | `false` | Show what would be changed without making changes |
| `--limit=N` | `1` | Number of documents to sample per collection |
| `--include=list` | (all) | Comma-separated list of collections to process |

## Target Collections

The script targets these collections with their respective TTL periods:

### 30-day retention
- `daily_checklists`
- `tasks` 
- `notifications`
- `messages`
- `daily_summary_by_location`
- `daily_summary_by_shift`

### 7-day retention
- `invites`
- `debug_logs`
- `debug_checklists`
- `debug_tasks`
- `debug_notifications`

### 90-day retention
- `daily_summary_by_organization`
- `daily_summary_by_organization_location`
- `daily_summary_by_organization_shift`
- `daily_summary_logs`

## How It Works

1. **Query Strategy**: For each collection, the script tries:
   - CollectionGroup query (for subcollections like `tasks`)
   - Top-level collection query (for root collections like `invites`)

2. **Document Selection**: Takes the first document found in each collection

3. **TTL Field Addition**: If the document doesn't have `expiresAt`:
   - Calculates appropriate expiration timestamp (now + TTL days)
   - Updates the document with the `expiresAt` field

4. **Safety**: Never overwrites existing `expiresAt` fields

## Output

The script provides detailed console output and a JSON summary:

```json
{
  "daily_checklists": {
    "updated": true,
    "docPath": "organizations/org123/locations/loc456/daily_checklists/check789",
    "ttlDays": 30
  },
  "invites": {
    "updated": false,
    "ttlDays": 7,
    "reason": "already has expiresAt"
  }
}
```

## Requirements

- Firebase Admin SDK initialized
- Appropriate Firestore permissions
- Environment variable `GOOGLE_APPLICATION_CREDENTIALS` set to service account key

## Next Steps

After running this script successfully:

1. **Enable TTL Policies in Firebase Console**:
   - Go to: Firestore → Data → Indexes & TTL
   - Click "Create TTL policy"
   - Set field name: `expiresAt`
   - Choose collection scope or database-wide

2. **Monitor TTL Behavior**:
   - TTL deletion is eventually consistent (may take up to 72 hours)
   - Check Firebase Console logs for TTL activity

3. **Deploy Updated Application**:
   - Ensure your app uses the TTL helper methods for all new document writes
   - This ensures all future documents automatically get `expiresAt` fields

## Troubleshooting

### "No documents found"
- Collections might be empty
- Check Firebase project selection
- Verify Firestore permissions

### Permission Errors
- Ensure service account has Firestore read/write permissions
- Check `GOOGLE_APPLICATION_CREDENTIALS` environment variable

### TTL Not Working After Console Setup
- Wait up to 72 hours for eventual consistency
- Check that TTL policy field name matches `expiresAt`
- Verify documents have valid Timestamp values in `expiresAt` field

## Example Run

```bash
$ node scripts/seedExpiresAt.js --dry-run

🌱 Firestore TTL Seeder Script
📋 Options: dryRun=true, limit=1

🎯 Processing 14 collections...

  Processing daily_checklists (30d TTL)...
    ✅ [DRY-RUN] Would update: organizations/abc/locations/xyz/daily_checklists/today
  Processing tasks (30d TTL)...
    ⏭️  Skipped: already has expiresAt
  Processing notifications (30d TTL)...
    ✅ [DRY-RUN] Would update: notifications/notif123

📊 Summary:
{
  "daily_checklists": { "updated": true, "docPath": "...", "ttlDays": 30 },
  "tasks": { "updated": false, "reason": "already has expiresAt", "ttlDays": 30 },
  "notifications": { "updated": true, "docPath": "...", "ttlDays": 30 }
}

✨ Completed! 2 collections would be seeded.
💡 Run without --dry-run to apply changes.
```
