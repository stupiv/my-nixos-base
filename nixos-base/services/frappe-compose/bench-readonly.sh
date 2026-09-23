#!/usr/bin/env bash
# bench-readonly.sh — host-side guard for read-only frappe-bench deployments.
#
# Environment (set on the systemd unit):
#   BENCH_DIR  (required)  path of the existing frappe-bench

set -euo pipefail

: "${BENCH_DIR:?BENCH_DIR is required}"

if [ -e "$BENCH_DIR" ]; then
  echo "WARNING: read-only mode; skipping frappe-bench rebuild." >&2
  echo "Changes to apps/branches will not take effect until read-only mode is disabled." >&2
  exit 0
fi
echo "ERROR: read-only mode is enabled but no frappe-bench exists at $BENCH_DIR." >&2
echo "A read-only deployment needs an existing bench; disable read-only mode" >&2
echo "for the first deployment, then re-enable it." >&2
exit 1
