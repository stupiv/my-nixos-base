#!/usr/bin/env bash
# frappe-bench-store.sh — build a Frappe bench into the Nix store
# The gcroot symlink is BOTH the GC protection AND the stable mount source.
#
# All configuration is read from the environment (set on the systemd unit by
# the Nix module's `environment = { ... }`):
#   GCROOT             gcroot symlink = stable mount source (required)
#   APPS_JSON          apps.json listing apps to install       (required)
#   FRAPPE_BRANCH      frappe branch, e.g. version-16          (required)
#   BUILD_IMAGE_TAG    frappe/build image tag, e.g. v16.26.2   (required)
#   BENCH_INIT_SCRIPT  bench-init.sh to run inside the container (required)
#   HASH_FILE          file storing SPEC_HASH for skip-compare
#                      (default: <GCROOT>-hash)
#   FORCE              "1" to rebuild even if spec matches     (default: 0)
set -euo pipefail

: "${GCROOT:?GCROOT is required}"
: "${APPS_JSON:?APPS_JSON is required}"
: "${FRAPPE_BRANCH:?FRAPPE_BRANCH is required}"
: "${BUILD_IMAGE_TAG:?BUILD_IMAGE_TAG is required}"
: "${BENCH_INIT_SCRIPT:?BENCH_INIT_SCRIPT is required}"
FORCE="${FORCE:-0}"
HASH_FILE="${HASH_FILE:-${GCROOT}-hash}"

mkdir -p "$(dirname "$GCROOT")" "$(dirname "$HASH_FILE")"

IMAGE="docker.io/frappe/build:${BUILD_IMAGE_TAG}"

# ── spec fingerprint: apps.json + frappe branch + builder tag ─
SPEC_HASH=$(cat "$APPS_JSON" <(echo "$FRAPPE_BRANCH") <(echo "$BUILD_IMAGE_TAG") | sha256sum | cut -c1-12)

# ── skip if hash matches AND the gcroot symlink is still valid ─
if [[ $FORCE -eq 0 && -e "$HASH_FILE" && -e "$GCROOT" ]] \
   && [[ "$(cat "$HASH_FILE")" == "$SPEC_HASH" ]]; then
  echo "==> spec ${SPEC_HASH} unchanged, skipping (use FORCE=1 to rebuild)" >&2
  exit 0
fi

# ── build the bench with frappe/build ─────────────────────────
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

USERNS_ARGS=()
if [[ $EUID -eq 0 ]]; then
  chown 1000:1000 "$work"
else
  USERNS_ARGS=("--userns=keep-id:uid=1000,gid=1000")
fi

podman run --rm \
  --name "frappe-bench-store-${SPEC_HASH}" \
  -v "$work":/home/frappe/frappe-bench \
  -v "$(realpath "$APPS_JSON")":/opt/frappe/apps.json:ro \
  -v "$(realpath "$BENCH_INIT_SCRIPT")":/opt/bench-init.sh:ro \
  -e "FRAPPE_BRANCH=${FRAPPE_BRANCH}" \
  "${USERNS_ARGS[@]}" \
  "$IMAGE" \
  bash /opt/bench-init.sh

# Sanity check: bench init must actually have produced a bench.
if [[ ! -d "$work/apps/frappe" ]]; then
  echo "ERROR: bench init did not produce apps/frappe — aborting" >&2
  exit 1
fi

# ── capture into the Nix store; gcroot symlink = mount source ─
storePath=$(nix store add-path --name "frappe-bench-${FRAPPE_BRANCH}-${SPEC_HASH}" "$work")
nix-store --add-root "$GCROOT" --realise "$storePath" >/dev/null

# ── record the spec hash atomically ──────────────────────────
tmp="$(mktemp "${HASH_FILE}.XXXXXX")"
printf '%s\n' "$SPEC_HASH" > "$tmp"
mv -f "$tmp" "$HASH_FILE"

echo "==> Store path: ${storePath}" >&2
echo "==> GC root:    ${GCROOT} -> $(readlink "$GCROOT")" >&2
echo "==> Hash file:  ${HASH_FILE}" >&2
