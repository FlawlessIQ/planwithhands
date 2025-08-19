Migration helper: migrate_checklist_templates_to_subcollections.js

Purpose:
Move checklist template tasks stored in the top-level `tasks` array on
`organizations/{orgId}/checklist_templates/{templateId}` into a
subcollection `organizations/{orgId}/checklist_templates/{templateId}/tasks`.

Usage:
 - Install dependencies (from repo root):
   npm install firebase-admin

 - Dry run to preview changes (no writes):
   GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json node scripts/migrate_checklist_templates_to_subcollections.js --dry-run

 - Apply changes:
   GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json node scripts/migrate_checklist_templates_to_subcollections.js

Notes:
 - The script will delete the top-level `tasks` field after creating subcollection docs.
 - Run the dry-run first and back up your Firestore data if unsure.
 - The script batches writes and commits every 400 writes to avoid limits.
 - Designed for the checklist templates shape seen in your database (array of maps).
