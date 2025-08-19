# Functions: dailyGenerator

This module contains a scheduled Cloud Function `scheduledDailyGenerator` that creates daily checklists and carries forward incomplete tasks.

Local emulator
1. Install dependencies in `functions/`:

```bash
cd functions
npm install
```

2. Start the emulator (Firestore + Functions):

```bash
npm run serve
```

Deploying

```bash
cd functions
npm run build
firebase deploy --only functions:scheduledDailyGenerator --project <PROJECT_ID>
```

Notes
- The function runs hourly and uses the `location.timezone` (fallback to `organization.timezone`) to compute local dates.
- Ensure the `luxon` dependency is installed in `functions/package.json`.
- The generator creates documents with `expiresAt` = createdAt + 30 days.

## TTL + Storage Ops Notes

- Firestore TTL (Time To Live) must be enabled for the `expiresAt` field to automatically remove ephemeral documents (daily checklists, daily tasks, invites, carry-forward tasks).
  - Enable TTL in the Firebase Console for the `expiresAt` field for the relevant environment.
  - Note: TTL does not cascade to subcollections. Every ephemeral document (for example every task doc in tasks subcollections) must include an `expiresAt` timestamp.

- Permanent collections MUST NOT have TTL enabled. These include (non-exhaustive):
  - `users`
  - `locations`
  - `shifts`
  - `checklist_templates`
  - `jobTypes`
  - training materials / docs
  - `stripe` subscription docs

- GCS lifecycle for task photos
  - The repository includes `lifecycle.json` which deletes objects under the `task_photos/` prefix after the configured number of days.
  - Apply lifecycle to the storage bucket once (example):

```
# Replace <bucket-name> with your production bucket
gsutil lifecycle set lifecycle.json gs://<bucket-name>
```

- Local testing with emulator
  - Use the Firestore emulator for safe testing of generator and carry-forward logic.
  - From `functions/` you can run tests under the emulator with:

```
# From repo root
cd functions
npm ci
npm run test:emulator
```

- Notes
  - The generator uses deterministic checklist IDs and deterministic-ish CF task ids to keep operations idempotent. Tests run against the emulator (see `functions/test/dailyGenerator.test.ts`).
  - Double-check that your environment's TTL policy and GCS lifecycle are applied to the intended resources before enabling them in production.
