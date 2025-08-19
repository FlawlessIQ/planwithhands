Daily checklist generation & TTL runbook

Purpose

This document explains how the Hands app handles ephemeral task photos and other short-lived data, and how to enable/verify server-side TTL and storage lifecycle rules.

Goals

- Ensure task photos and ephemeral in-app messages/notifications are removed automatically after a retention window (default: 30 days).
- Provide safe rollback and verification steps.

Overview

- Firestore: collection documents that are ephemeral (notifications, user messages, task photo markers) include an `expiresAt` Timestamp field. A server-side Firestore TTL policy should be enabled on the `expiresAt` field to automatically delete these documents.
- Storage: task photos are uploaded under the `task_photos/` prefix. Use a Cloud Storage lifecycle rule to delete objects older than the retention period.

Files & locations in repo

- Storage lifecycle config: `lifecycle.json` (contains a rule for `task_photos/`).
- Storage rules: `storage.rules` includes `match /task_photos/{fileName}`.
- Client photo uploads: `lib/services/daily_checklist_service.dart::uploadTaskPhoto` writes files under `task_photos/` and updates Firestore task docs via `updateTaskPhotoInSubcollection` which now writes `expiresAt`.
- Notifications: `lib/data/repositories/notification_repository.dart` now writes `expiresAt` for organization notifications.
- Schedule messages: `lib/ui/schedule_page.dart` now writes `expiresAt` when adding `users/{userId}/messages`.

Enabling Firestore TTL (Console)

1. Open the Google Cloud Console → Firestore.
2. In the left menu choose "Data" then "Indexes & TTL" (or the TTL panel).
3. Under "Create TTL policy" choose the collection scope (for single-field TTL you can apply to your whole DB) and select the field name `expiresAt`.
4. Confirm and enable the policy. Note: TTL is eventually consistent — deletions may take some time.

Enabling GCS lifecycle for `task_photos/` (gsutil)

1. Ensure you have the Cloud SDK and `gsutil` configured with the right project and permissions.
2. The repo contains `lifecycle.json` with the rule targeting `task_photos/`.
3. Apply the lifecycle rule:

```bash
# Replace <BUCKET_NAME> with your storage bucket
gsutil lifecycle set lifecycle.json gs://<BUCKET_NAME>
```

4. Verify the applied lifecycle:

```bash
gsutil lifecycle get gs://<BUCKET_NAME>
```

Notes: lifecycle rules apply to objects that match prefixes; newly uploaded objects will be evaluated by the rule.

Rollback steps

If enabling TTL or lifecycle causes unexpected deletions or other issues, follow these steps:

1. Disable the TTL policy in Firestore (Console → TTL panel → disable). This prevents further automatic deletions but does not restore already-deleted documents.
2. Remove or update the lifecycle rule on the GCS bucket:

```bash
# Clear lifecycle rules
gsutil lifecycle clear gs://<BUCKET_NAME>
```

3. Restore data from backups if available:
  - For Firestore: restore from scheduled exports or backups. See Cloud Firestore backup & restore docs.
  - For Storage: restore from any offsite backup or snapshot if available.

4. Investigate why documents were being deleted (check TTL rules, timestamp accuracy, and client code writing `expiresAt` incorrectly). Check logs (Cloud Audit Logs) to see delete operations and origin.

Testing locally

- Use emulators for Firestore and Storage when possible. TTL is not enforced by the emulator; lifecycle rules are also not enforced locally. Test client behavior by verifying that `expiresAt` is written and that the storage path uses the intended prefix.

Follow-ups / Suggested improvements

- Audit all places that write ephemeral content and ensure `expiresAt` is set consistently.
- Add unit tests or integration tests that assert the presence of `expiresAt` on ephemeral writes.
- Consider adding a small Cloud Function that periodically validates ephemeral collections and emits alerts if documents exceed expected retention windows (useful as a safety net).

Contact

If you want, I can:
- Continue migrating remaining `debugPrint` occurrences to `logger.*`.
- Add automated checks (lint or test) that assert ephemeral writes include `expiresAt`.
- Create a small script to apply the gsutil lifecycle command with a parameterized bucket name.
