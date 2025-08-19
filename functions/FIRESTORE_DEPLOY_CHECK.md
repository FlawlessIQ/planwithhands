# Firestore Deploy Check

This repository includes a safety check to ensure you only deploy Firebase Functions when the project's default Firestore database is configured in Native mode.

Why
- Deploying functions to a project whose default Firestore database is in Datastore mode can cause runtime failures. This check ensures the default `(default)` Firestore DB exists and is in NATIVE_MODE.

What the check does
- Runs `firebase firestore:databases:list --project plan-with-hands` and parses the output.
- Ensures a `(default)` database exists and has mode `NATIVE_MODE`.
- If the check fails, the deploy is aborted.

How to use
- Run `npm run check:firestore` in the `functions/` folder to perform the check manually.
- `npm run deploy` will run the check automatically before building and deploying functions.

Notes
- The script uses the Firebase CLI and assumes you are logged in and have the project `plan-with-hands` available.
- No manual input is required; the script exits non-zero on failure so CI pipelines will stop the deploy.
