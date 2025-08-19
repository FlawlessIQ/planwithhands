#!/usr/bin/env bash
set -euo pipefail

FUNC_URL="https://us-central1-plan-with-hands.cloudfunctions.net/migrateChecklistTemplates"
ORG_ID="FErQ4pkcrCovJ7T6L13M"

echo "==> Final scoped DRY-RUN (diag=1) on org: $ORG_ID"
DRY_JSON="$(curl -fsS "$FUNC_URL?dryRun=true&diag=1&orgId=$ORG_ID")" || { echo "Dry-run failed"; exit 1; }
echo "$DRY_JSON" | jq .

ELIGIBLE="$(echo "$DRY_JSON" | jq -r '.templatesEligible // 0')"
DBID="$(echo "$DRY_JSON" | jq -r '.databaseId // "(missing)"')"
echo "databaseId: $DBID"
if [[ "$ELIGIBLE" -lt 1 ]]; then
  echo "No eligible templates found; aborting."
  exit 2
fi

read -rp "Proceed with REAL migration for org $ORG_ID (yes/no)? " ans
if [[ "$ans" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

echo "==> Running REAL migration for org: $ORG_ID"
RUN_JSON="$(curl -fsS "$FUNC_URL?dryRun=false&orgId=$ORG_ID")" || { echo "Real run failed"; exit 1; }
echo "$RUN_JSON" | jq .

echo "==> Manually verify Firestore now:"
echo " • Each migrated template has /tasks subcollection"
echo " • Parent has migratedTasks:true and tasksCount"
echo " • Old top-level tasks array is removed"
read -rp "When verified, run FULL migration for ALL orgs (yes/no)? " all
if [[ "$all" != "yes" ]]; then
  echo "Stopping after single-org migration."
  exit 0
fi

echo "==> Running FULL project migration"
FULL_JSON="$(curl -fsS "$FUNC_URL?dryRun=false")" || { echo "Full run failed"; exit 1; }
echo "$FULL_JSON" | jq .

echo "==> Done."
