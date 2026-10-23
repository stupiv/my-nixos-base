#!/usr/bin/env bash
set -euo pipefail

# Values injected as container environment variables (see Nix module):
#   SITE                 (required) the Frappe site name
#   MARIADB_SOCKET       (required) in-container MariaDB socket path
#   VALKEY_CACHE_SOCKET  (required) in-container valkey cache socket path
#   VALKEY_QUEUE_SOCKET  (required) in-container valkey queue socket path
#   READONLY             (required) "1" when read-only mode is enabled, else "0"
# Conditional (only for `bench new-site`):
#   INIT_ADMIN_PASSWORD, DB_PASSWORD  (from the sops envfile)

: "${SITE:?SITE is required}"
: "${MARIADB_SOCKET:?MARIADB_SOCKET is required}"
: "${VALKEY_CACHE_SOCKET:?VALKEY_CACHE_SOCKET is required}"
: "${VALKEY_QUEUE_SOCKET:?VALKEY_QUEUE_SOCKET is required}"
: "${READONLY:?READONLY is required}"

until [ -S "$MARIADB_SOCKET" ] && \
      [ -S "$VALKEY_CACHE_SOCKET" ] && \
      [ -S "$VALKEY_QUEUE_SOCKET" ]; do
  echo "Waiting for unix sockets..."
  sleep 5
done

export start=$(date +%s)
until [[ -n `grep -hs ^ sites/common_site_config.json | jq -r ".db_socket // empty"` ]] && \
      [[ -n `grep -hs ^ sites/common_site_config.json | jq -r ".redis_cache // empty"` ]] && \
      [[ -n `grep -hs ^ sites/common_site_config.json | jq -r ".redis_queue // empty"` ]]; do
  echo "Waiting for sites/common_site_config.json to be created"
  sleep 5
  if (( $(date +%s) - start > 120 )); then
    echo "could not find sites/common_site_config.json with required keys"
    exit 1
  fi
done
echo "sites/common_site_config.json found"

if [ -f "sites/$SITE/.site-created" ]; then
  echo "Site $SITE already created; nothing to do"
elif [ "$READONLY" = "1" ]; then
  echo "ERROR: readOnlyMode is enabled but site $SITE does not exist yet." >&2
  echo "Refusing to create a new site in read-only mode; disable readOnlyMode first." >&2
  exit 1
elif [ -d "sites/$SITE" ]; then
  echo "ERROR: sites/$SITE exists but has no .site-created marker." >&2
  echo "A previous 'bench new-site' probably failed halfway, or the site" >&2
  echo "predates the marker convention. Refusing to touch it." >&2
  echo "" >&2
  echo "Fix manually, then restart this service:" >&2
  echo "  - if the site is healthy:  touch sites/$SITE/.site-created" >&2
  echo "  - if it is half-created:   bench drop-site $SITE --db-root-username=root --db-root-password=... --force --no-backup" >&2
  exit 1
else
  : "${INIT_ADMIN_PASSWORD:?INIT_ADMIN_PASSWORD is required for 'bench new-site'}"
  : "${DB_PASSWORD:?DB_PASSWORD is required for 'bench new-site'}"
  bench new-site --mariadb-user-host-login-scope='%' --db-root-username=root \
    --admin-password="$INIT_ADMIN_PASSWORD" \
    --db-root-password="$DB_PASSWORD" \
    --set-default "$SITE"
  touch "sites/$SITE/.site-created"
fi
