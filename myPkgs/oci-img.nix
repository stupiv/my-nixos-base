{
  lib,
  newScope,
}: (lib.makeScope newScope (self: {
  # mariadb_v11_8 = "docker.io/mariadb:11.8.8"; # See https://hub.docker.com/_/mariadb/tags
  # chatwoot_v4 = "docker.io/chatwoot/chatwoot:v4.14.1-ce"; # See https://hub.docker.com/r/chatwoot/chatwoot/tags
  # pgvector_v0_8_pg18 = "docker.io/pgvector/pgvector:0.8.2-pg18-trixie"; # See https://hub.docker.com/r/pgvector/pgvector/tags
  # valkey_v8 = "docker.io/valkey/valkey:8.1.8-alpine"; # See https://hub.docker.com/r/valkey/valkey/tags
}))
