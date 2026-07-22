#!/usr/bin/env bash
# frappe-bench-store.sh — build a Frappe bench into the Nix store
# The gcroot symlink is BOTH the GC protection AND the stable mount source.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  frappe-bench-store.sh \
      --gcroot PATH            gcroot symlink = stable mount source
                               (e.g. /var/lib/frappe/bench-current)
      --apps-json PATH         apps.json listing apps to install
      --frappe-branch BRANCH   frappe branch (e.g. version-16)
      --build-image-tag TAG    frappe/build image tag (e.g. v16.26.2)
      [--hash-file PATH]       file storing SPEC_HASH for skip-comparison
                               (default: <gcroot>-hash)
      [--force]                rebuild even if spec matches
EOF
  exit 1
}

# ── defaults ──────────────────────────────────────────────────
GCROOT=""; APPS_JSON=""; FRAPPE_BRANCH=""
TAG=""; HASH_FILE=""; FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gcroot)          GCROOT="$2";        shift 2 ;;
    --apps-json)       APPS_JSON="$2";     shift 2 ;;
    --frappe-branch)   FRAPPE_BRANCH="$2"; shift 2 ;;
    --build-image-tag) TAG="$2";           shift 2 ;;
    --hash-file)       HASH_FILE="$2";     shift 2 ;;
    --force)           FORCE=1;            shift   ;;
    -h|--help)         usage ;;
    *) echo "unknown flag: $1" >&2; usage ;;
  esac
done

[[ -n "$GCROOT" && -n "$APPS_JSON" && -n "$FRAPPE_BRANCH" && -n "$TAG" ]] || usage
[[ -n "$HASH_FILE" ]] || HASH_FILE="${GCROOT}-hash"
mkdir -p "$(dirname "$GCROOT")" "$(dirname "$HASH_FILE")"

IMAGE="docker.io/frappe/build:${TAG}"

# ── spec fingerprint: apps.json + frappe branch + builder tag ─
SPEC_HASH=$(cat "$APPS_JSON" <(echo "$FRAPPE_BRANCH") <(echo "$TAG") | sha256sum | cut -c1-12)

# ── skip if hash matches AND the gcroot symlink is still valid ─
if [[ $FORCE -eq 0 && -e "$HASH_FILE" && -e "$GCROOT" ]] \
   && [[ "$(cat "$HASH_FILE")" == "$SPEC_HASH" ]]; then
  echo "==> spec ${SPEC_HASH} unchanged, skipping (use --force to rebuild)" >&2
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
  "${USERNS_ARGS[@]}" \
  "$IMAGE" \
  bash -c "
    set -euo pipefail
    bench init --ignore-exist --apps_path=/opt/frappe/apps.json \
      --frappe-branch ${FRAPPE_BRANCH} --no-procfile --no-backups \
      --skip-redis-config-generation --verbose /home/frappe/frappe-bench
    cd /home/frappe/frappe-bench
    echo '{}' > sites/common_site_config.json
    find apps -mindepth 1 -path '*/.git' -prune -exec rm -rf {} +
    rm -rf /home/frappe/frappe-bench/logs
  "

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
