#!/usr/bin/env bash
set -euo pipefail

# Default to the plan-with-hands project unless explicitly overridden.
FIREBASE_PROJECT_DEFAULT="plan-with-hands"
FIREBASE_PROJECT="${FIREBASE_PROJECT:-$FIREBASE_PROJECT_DEFAULT}"
REGION="${FIREBASE_REGION:-us-central1}"

# Allow passing the exact URL (helps if region differs).
# If MIGRATE_URL is set, it takes precedence over REGION/PROJECT.
if [[ -n "${MIGRATE_URL:-}" ]]; then
  URL="$MIGRATE_URL"
else
  URL="https://${REGION}-${FIREBASE_PROJECT}.cloudfunctions.net/migrateChecklistTemplates"
fi

echo "==> Using project: ${FIREBASE_PROJECT} (region: ${REGION})"
firebase use "${FIREBASE_PROJECT}"
firebase deploy --only functions:migrateChecklistTemplates

# Helper that ensures the endpoint returns JSON and fails fast otherwise
curl_json() {
  local endpoint="$1"
  local resp
  resp=$(curl -sS "$endpoint" || true)
  # Expect JSON (first non-space char is "{"); otherwise print and exit
  # shellcheck disable=SC2001
  local first
  first=$(echo "$resp" | sed -n 's/^\s*\(.\).*$/\1/p' | head -n1)
  if [[ "$first" != "{" ]]; then
    echo "ERROR: expected JSON from: $endpoint"
    echo "----- BEGIN RESPONSE -----"
    echo "$resp"
    echo "------ END RESPONSE ------"
    exit 1
  fi
  echo "$resp"
}

echo "==> DRY-RUN (no writes)"
curl_json "${URL}?dryRun=true" | tee /tmp/migrate_checklist_templates_dryrun.json
echo ""
echo "Review the dry-run JSON above. If it looks correct, type 'yes' to proceed with real migration."
read -r -p "Proceed with real migration? (yes/no): " yn
if [[ "${yn}" != "yes" ]]; then
  echo "Aborting without changes."
  exit 0
fi

echo "==> RUNNING REAL MIGRATION (writes enabled)"
curl_json "${URL}?dryRun=false" | tee /tmp/migrate_checklist_templates_run.json

echo ""
echo "==> DONE."
echo "Dry-run output: /tmp/migrate_checklist_templates_dryrun.json"
echo "Run output    : /tmp/migrate_checklist_templates_run.json"
echo ""
echo "Optional cleanup:"
echo "  firebase functions:delete migrateChecklistTemplates"
