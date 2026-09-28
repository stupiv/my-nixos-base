#!/usr/bin/env bash
set -euo pipefail

# Values injected as container environment variables (see Nix module):
#   MARIADB_SERVICE                 (required) DB host (container/service name)
#   MARIADB_SOCKET                  (required) in-container MariaDB socket path
#   VALKEY_CACHE_SOCKET             (required) in-container valkey cache socket path
#   VALKEY_QUEUE_SOCKET             (required) in-container valkey queue socket path
#   SOCKETIO_PORT                   (required) socket.io port
#   MAINTENANCE_MODE                (required) "1" / "0"
#   ALLOW_READS_DURING_MAINTENANCE  (required) "1" / "0"

: "${MARIADB_SERVICE:?MARIADB_SERVICE is required}"
: "${MARIADB_SOCKET:?MARIADB_SOCKET is required}"
: "${VALKEY_CACHE_SOCKET:?VALKEY_CACHE_SOCKET is required}"
: "${VALKEY_QUEUE_SOCKET:?VALKEY_QUEUE_SOCKET is required}"
: "${SOCKETIO_PORT:?SOCKETIO_PORT is required}"
: "${MAINTENANCE_MODE:?MAINTENANCE_MODE is required}"
: "${ALLOW_READS_DURING_MAINTENANCE:?ALLOW_READS_DURING_MAINTENANCE is required}"

if [ ! -f sites/common_site_config.json ]; then
  echo "{}" > sites/common_site_config.json
fi

ls -1 apps > sites/apps.txt

bench set-config -g db_type mariadb
bench set-config -g db_host "$MARIADB_SERVICE"
bench set-config -g db_socket "$MARIADB_SOCKET"
bench set-config -g redis_cache "unix://$VALKEY_CACHE_SOCKET"
bench set-config -g redis_queue "unix://$VALKEY_QUEUE_SOCKET"
bench set-config -g redis_socketio "unix://$VALKEY_QUEUE_SOCKET"
bench set-config -gp socketio_port "$SOCKETIO_PORT"
bench set-config -gp maintenance_mode "$MAINTENANCE_MODE"
bench set-config -gp allow_reads_during_maintenance "$ALLOW_READS_DURING_MAINTENANCE"
