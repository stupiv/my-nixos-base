{
  nixpkgs.overlays = [
    (final: prev: {
      myPkgs = prev.myPkgs.overrideScope (myPkgsFinal: myPkgsPrev: {
        oci-img = prev.lib.makeScope prev.newScope (self: {
          n8n_v2 = "docker.io/n8nio/n8n:2.28.7"; # https://hub.docker.com/r/n8nio/n8n/tags
          mariadb_v11_8 = "docker.io/mariadb:11.8.8"; # https://hub.docker.com/_/mariadb/tags
          chatwoot_v4 = "docker.io/chatwoot/chatwoot:v4.14.1-ce"; # https://hub.docker.com/r/chatwoot/chatwoot/tags
          pgvector_v0_8_pg18 = "docker.io/pgvector/pgvector:0.8.2-pg18-trixie"; # https://hub.docker.com/r/pgvector/pgvector/tags
          valkey_v8 = "docker.io/valkey/valkey:8.1.8-alpine"; # https://hub.docker.com/r/valkey/valkey/tags
        });
      });
    })
  ];
}
