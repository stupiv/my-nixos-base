#!/usr/bin/env bash
set -euo pipefail

# Values injected as container environment variables (see Nix module):
#   SITE          (required) the Frappe site name
#   APPS          (required) space-separated list of enabled apps (install loop)
#   READONLY      (required) "1" when read-only mode is enabled, else "0"

: "${SITE:?SITE is required}"
: "${APPS:?APPS is required}"
: "${READONLY:?READONLY is required}"

if [ "$READONLY" = "1" ]; then
  echo "readOnlyMode is enabled; skipping app sync and migrate."
  exit 0
fi

export start=$(date +%s)
until [ -f "sites/$SITE/.site-created" ]; do
  echo "Waiting for site $SITE to be created..."
  sleep 5
  if (( $(date +%s) - start > 600 )); then
    echo "site $SITE was not created in time" >&2
    exit 1
  fi
done

installed=$(bench --site "$SITE" list-apps -f json | jq -r --arg s "$SITE" '.[$s][]')

for app in $APPS; do
  if ! grep -qx "$app" <<< "$installed"; then
    echo "Installing new app: $app"
    bench --site "$SITE" install-app "$app"
  fi
done

echo "Running migrate for site $SITE"
bench --site "$SITE" migrate
