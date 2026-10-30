#!/usr/bin/env bash
# bench-init.sh — runs INSIDE the frappe/build container.
# Extracted from frappe-bench-store's inline `bash -c "..."`.
#
# Environment provided by frappe-bench-store.sh at podman run time:
#   FRAPPE_BRANCH  (required)
# Mounted read-only by frappe-bench-store.sh:
#   /opt/frappe/apps.json
#   /opt/bench-init.sh  (this file)

set -euo pipefail

: "${FRAPPE_BRANCH:?FRAPPE_BRANCH is required}"

bench init --ignore-exist --apps_path=/opt/frappe/apps.json \
  --frappe-branch "$FRAPPE_BRANCH" --no-procfile --no-backups \
  --skip-redis-config-generation --verbose /home/frappe/frappe-bench
cd /home/frappe/frappe-bench
echo '{}' > sites/common_site_config.json
find apps -mindepth 1 -path '*/.git' -prune -exec rm -rf {} +
rm -rf /home/frappe/frappe-bench/logs
