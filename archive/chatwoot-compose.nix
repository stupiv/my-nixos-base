{
  config,
  lib,
  ...
}:
with lib; let
  enabled-chatwoot-compose = filterAttrs (_: cfg: cfg.enable) config.myOpt.chatwoot-compose;
  in-container-valkey-socket-folder = "/run/valkey";
  in-container-valkey-socket-path = "${in-container-valkey-socket-folder}/valkey.sock";
  in-container-chatwoot-socket-folder = "/run/chatwoot";
  in-container-pgvector-socket-folder = "/var/run/postgresql";
  in-container-valkey-data-dir = "/data";
  POSTGRES_USER = "chatwoot";
  POSTGRES_DB = "chatwoot";
  autoStart = false;
in {
  options.myOpt.chatwoot-compose = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...}: {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        proxy-compose = mkOption {
          type = types.anything;
          default = {};
        };
        chatwoot = {
          image = mkOption {
            type = types.singleLineStr;
            example = "chatwoot/chatwoot:v4.14.1-ce";
            # https://hub.docker.com/r/chatwoot/chatwoot/tags
          };
          stateDir = mkOption {
            type = types.singleLineStr;
            example = "/var/lib/<name>/chatwoot_v4";
          };
        };
        pgvector = {
          image = mkOption {
            type = types.singleLineStr;
            example = "pgvector/pgvector:0.8.2-pg18-trixie";
            # https://hub.docker.com/r/pgvector/pgvector/tags
          };
          stateDir = mkOption {
            type = types.singleLineStr;
            example = "/var/lib/<name>/pgvector_v0_8_pg18";
          };
        };
        valkey = {
          image = mkOption {
            type = types.singleLineStr;
            example = "valkey/valkey:8.1.8-alpine";
            # https://hub.docker.com/r/valkey/valkey/tags
          };
          stateDir = mkOption {
            type = types.singleLineStr;
            example = "/var/lib/<name>/valkey_v8";
          };
        };
        chatwoot.envfile-key = mkOption {
          type = types.singleLineStr;
          default = "${name}/chatwoot_envfile";
          # https://raw.githubusercontent.com/chatwoot/chatwoot/develop/.env.example
          ## SECRET_KEY_BASE=
          # These take from valkey and pgvector envfile
          ## REDIS_PASSWORD=
          ## POSTGRES_PASSWORD=
        };
        valkey.envfile-key = mkOption {
          type = types.singleLineStr;
          default = "${name}/valkey_envfile";
          # REDIS_PASSWORD=
        };
        pgvector.envfile-key = mkOption {
          type = types.singleLineStr;
          default = "${name}/pgvector_envfile";
          # POSTGRES_PASSWORD=
        };
        chatwoot.socket-folder = mkOption {
          type = types.singleLineStr;
          default = "/run/${name}/chatwoot";
          readOnly = true;
        };
        chatwoot.socket-filename = mkOption {
          type = types.singleLineStr;
          default = "chatwoot.sock";
          readOnly = true;
        };
        chatwoot.rails.serviceName = mkOption {
          type = types.singleLineStr;
          default = "${name}-rails";
          readOnly = true;
        };
        chatwoot.sidekiq.serviceName = mkOption {
          type = types.singleLineStr;
          default = "${name}-sidekiq";
          readOnly = true;
        };
        chatwoot.prepare.serviceName = mkOption {
          type = types.singleLineStr;
          default = "${name}-prepare";
          readOnly = true;
        };
        pgvector.serviceName = mkOption {
          type = types.singleLineStr;
          default = "${name}-pgvector";
          readOnly = true;
        };
        pgvector.socket-folder = mkOption {
          type = types.singleLineStr;
          default = "/run/${name}/pgvector";
          readOnly = true;
        };
        valkey.serviceName = mkOption {
          type = types.singleLineStr;
          default = "${name}-valkey";
          readOnly = true;
        };
        valkey.socket-folder = mkOption {
          type = types.singleLineStr;
          default = "/run/${name}/valkey";
          readOnly = true;
        };
      };
    }));
  };

  config = {
    sops.secrets = mkMerge (mapAttrsToList (
        name: cfg: {
          ${cfg.chatwoot.envfile-key} = {};
          ${cfg.pgvector.envfile-key} = {};
          ${cfg.valkey.envfile-key} = {};
        }
      )
      enabled-chatwoot-compose);

    myOpt.proxy-compose =
      mapAttrs' (name: cfg: (nameValuePair cfg.chatwoot.rails.serviceName (mkMerge [
        cfg.proxy-compose
        {
          localMode.port = mkDefault 18093;
          sleep-on-idle = {
            health-check.path = "/api";
            endpoints.default = {
              origin.socket-address = "${cfg.chatwoot.socket-folder}/${cfg.chatwoot.socket-filename}";
            };
            dependsOn = [
              cfg.chatwoot.sidekiq.serviceName
              cfg.chatwoot.prepare.serviceName
              cfg.pgvector.serviceName
              cfg.valkey.serviceName
            ];
          };
        }
      ])))
      enabled-chatwoot-compose;

    systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: [
        "d ${cfg.chatwoot.stateDir} - - - - -"
        "d ${cfg.pgvector.stateDir} - - - - -"
        "d ${cfg.valkey.stateDir} - - - - -"
        "d ${cfg.chatwoot.socket-folder} - - - - -"
        "d ${cfg.pgvector.socket-folder} - - - - -"
        "d ${cfg.valkey.socket-folder} - - - - -"
      ])
      enabled-chatwoot-compose);

    systemd.services =
      mapAttrs' (name: cfg: (nameValuePair cfg.chatwoot.prepare.serviceName {
        serviceConfig = {
          RemainAfterExit = true;
        };
      }))
      enabled-chatwoot-compose;

    virtualisation.oci-containers.containers = mkMerge (mapAttrsToList (
        name: cfg: let
          chatwoot_base = rec {
            inherit autoStart;
            inherit (cfg.chatwoot) image;
            environmentFiles = [
              config.sops.secrets.${cfg.chatwoot.envfile-key}.path
              config.sops.secrets.${cfg.pgvector.envfile-key}.path
              config.sops.secrets.${cfg.valkey.envfile-key}.path
            ];
            dependsOn = [cfg.pgvector.serviceName cfg.valkey.serviceName];
            environment = {
              NODE_ENV = "production";
              RAILS_ENV = "production";
              INSTALLATION_ENV = "docker";
              REDIS_URL = "unix://${in-container-valkey-socket-path}";
              POSTGRES_HOST = in-container-pgvector-socket-folder;
              POSTGRES_USERNAME = POSTGRES_USER;
              POSTGRES_DATABASE = POSTGRES_DB;
              PIDFILE = "/tmp/server.pid";
            };
            volumes = [
              "${cfg.chatwoot.stateDir}:/app/storage"
              "${cfg.pgvector.socket-folder}:${environment.POSTGRES_HOST}"
              "${cfg.valkey.socket-folder}:${in-container-valkey-socket-folder}"
            ];
          };
        in {
          ${cfg.chatwoot.prepare.serviceName} = mkMerge [
            chatwoot_base
            {
              inherit (cfg.chatwoot.prepare) serviceName;
              entrypoint = "docker/entrypoints/rails.sh";
              cmd = ["bundle" "exec" "rails" "db:chatwoot_prepare"];
            }
          ];

          ${cfg.chatwoot.rails.serviceName} = mkMerge [
            chatwoot_base
            {
              inherit (cfg.chatwoot.rails) serviceName;
              dependsOn = [cfg.chatwoot.prepare.serviceName];
              entrypoint = "docker/entrypoints/rails.sh";
              cmd = ["bundle" "exec" "puma" "-b" "unix://${in-container-chatwoot-socket-folder}/${cfg.chatwoot.socket-filename}"];
              volumes = [
                "${cfg.chatwoot.socket-folder}:${in-container-chatwoot-socket-folder}"
              ];
            }
          ];

          ${cfg.chatwoot.sidekiq.serviceName} = mkMerge [
            chatwoot_base
            {
              inherit (cfg.chatwoot.sidekiq) serviceName;
              dependsOn = [cfg.chatwoot.prepare.serviceName];
              cmd = ["bundle" "exec" "sidekiq" "-C" "config/sidekiq.yml"];
            }
          ];

          ${cfg.pgvector.serviceName} = rec {
            inherit autoStart;
            inherit (cfg.pgvector) image serviceName;
            environmentFiles = [config.sops.secrets.${cfg.pgvector.envfile-key}.path];
            environment = {
              inherit POSTGRES_USER POSTGRES_DB;
              PGDATA = "/var/lib/postgresql/data";
            };
            cmd = [
              "postgres"
              "-c"
              "listen_addresses="
              "-c"
              "unix_socket_directories=${in-container-pgvector-socket-folder}"
            ];
            volumes = [
              "${cfg.pgvector.stateDir}:${environment.PGDATA}"
              "${cfg.pgvector.socket-folder}:${in-container-pgvector-socket-folder}"
            ];
          };

          ${cfg.valkey.serviceName} = {
            inherit autoStart;
            inherit (cfg.valkey) image serviceName;
            environmentFiles = [config.sops.secrets.${cfg.valkey.envfile-key}.path];
            entrypoint = "sh";
            cmd = [
              "-c"
              "exec redis-server --port 0 --unixsocket ${in-container-valkey-socket-path} --unixsocketperm 777 --requirepass \"$REDIS_PASSWORD\" --dir ${in-container-valkey-data-dir}"
            ];
            volumes = [
              "${cfg.valkey.stateDir}:${in-container-valkey-data-dir}"
              "${cfg.valkey.socket-folder}:${in-container-valkey-socket-folder}"
            ];
          };
        }
      )
      enabled-chatwoot-compose);
  };
}
