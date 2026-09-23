{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  enabled-frappe-compose = filterAttrs (_: cfg: cfg.enable) config.myOpt.frappe-compose;
  autoStart = false;

  in-container-bench-dir = "/home/frappe/frappe-bench";
  sites-path = "/sites";
  logs-path = "/logs";
  assets-path = "${sites-path}/assets";
  in-container-mariadb-data-dir = "/var/lib/mysql";
  in-container-valkey-data-dir = "/data";
  in-container-frappe-socket-folder = "/run/frappe";
  in-container-mariadb-socket-folder = "/run/mysqld";
  in-container-valkey-cache-socket-folder = "/run/valkey-cache";
  in-container-valkey-queue-socket-folder = "/run/valkey-queue";
  mariadb-socket-name = "mysqld.sock";
  valkey-socket-name = "valkey.sock";
  frappe-socket-name = "gunicorn.sock";
  socketio_port = "9000";

  in-container-sites-dir = "${in-container-bench-dir}${sites-path}";
  in-container-logs-dir = "${in-container-bench-dir}${logs-path}";
  mariadb-socket = "${in-container-mariadb-socket-folder}/${mariadb-socket-name}";
  valkey-cache-socket = "${in-container-valkey-cache-socket-folder}/${valkey-socket-name}";
  valkey-queue-socket = "${in-container-valkey-queue-socket-folder}/${valkey-socket-name}";
  frappe-socket = "${in-container-frappe-socket-folder}/${frappe-socket-name}";

  mkAppsJson = name: cfg: let
    enabledApps = filterAttrs (_: a: a.enable) cfg.frappe.apps;
    appsList = mapAttrsToList (_: a: {inherit (a) url branch;}) enabledApps;
  in
    pkgs.writeText "apps-${name}.json" (builtins.toJSON appsList);

  frappe-bench-store = getExe (pkgs.writeShellApplication {
    name = "frappe-bench-store";
    runtimeInputs = with pkgs; [podman nix coreutils gnugrep gnused];
    text = builtins.readFile ./frappe-bench-store.sh;
  });

  # bench-init.sh runs inside the frappe/build container. Made a store path
  bench-init-script = pkgs.writeScript "bench-init.sh" (builtins.readFile ./bench-init.sh);
  create-site-script = pkgs.writeScript "create-site.sh" (builtins.readFile ./create-site.sh);
  migrate-script = pkgs.writeScript "migrate.sh" (builtins.readFile ./migrate.sh);
  configurator-script = pkgs.writeScript "configurator.sh" (builtins.readFile ./configurator.sh);
in {
  options.myOpt.frappe-compose = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({
      name,
      config,
      ...
    }: {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        proxy-compose = mkOption {
          type = types.anything;
          default = {};
        };
        frappe = {
          readOnlyMode = mkOption {
            type = types.bool;
            default = false;
          };
          sitesDir = mkOption {
            type = types.singleLineStr;
            example = "/var/lib/test/frappe_v16/frappe_v16${sites-path}";
          };
          logsDir = mkOption {
            type = types.singleLineStr;
            example = "/var/lib/test/frappe_v16/frappe_v16${logs-path}";
          };
          benchDir = mkOption {
            type = types.singleLineStr;
            example = "/var/lib/test/frappe_v16/frappe_v16/frappe-bench";
          };
          apps = mkOption {
            type = types.attrsOf (types.submodule ({name, ...}: {
              options = {
                enable = mkOption {
                  type = types.bool;
                  default = true;
                };
                url = mkOption {
                  type = types.singleLineStr;
                  default = "https://github.com/frappe/${name}";
                };
                branch = mkOption {
                  type = types.singleLineStr;
                };
              };
            }));
          };
          branch = mkOption {
            type = types.singleLineStr;
            default = config.frappe.base.tag; # See https://raw.githubusercontent.com/frappe/frappe_docker/main/docker-bake.hcl
            readOnly = true;
          };
          base = {
            tag = mkOption {
              type = types.singleLineStr;
              example = "v16.25.0";
            };
            image = mkOption {
              type = types.singleLineStr;
              default = "docker.io/frappe/base:${config.frappe.base.tag}";
              readOnly = true;
            };
          };
          build = {
            serviceName = mkOption {
              type = types.singleLineStr;
              default = "${name}-build";
              readOnly = true;
            };
            tag = mkOption {
              type = types.singleLineStr;
              default = config.frappe.apps.erpnext.branch; # See https://raw.githubusercontent.com/frappe/frappe_docker/main/docker-bake.hcl
              readOnly = true;
              example = "v16.26.2";
            };
          };
          frontend = {
            serviceName = mkOption {
              type = types.singleLineStr;
              default = "${name}-frontend";
              readOnly = true;
            };
            port = mkOption {
              type = types.port;
            };
            listen-address = mkOption {
              type = types.singleLineStr;
              default = "127.0.0.1";
            };
          };
          backend = {
            serviceName = mkOption {
              type = types.singleLineStr;
              default = "${name}-backend";
              readOnly = true;
            };
            socket-folder = mkOption {
              type = types.singleLineStr;
              default = "/run/${name}/backend";
              readOnly = true;
            };
          };
          configurator.serviceName = mkOption {
            type = types.singleLineStr;
            default = "${name}-configurator";
            readOnly = true;
          };
          siteName = mkOption {
            type = types.singleLineStr;
            default = "frontend";
          };
          create-site.serviceName = mkOption {
            type = types.singleLineStr;
            default = "${name}-create-site";
            readOnly = true;
          };
          migrate.serviceName = mkOption {
            type = types.singleLineStr;
            default = "${name}-migrate";
            readOnly = true;
          };
          queue-long.serviceName = mkOption {
            type = types.singleLineStr;
            default = "${name}-queue-long";
            readOnly = true;
          };
          queue-short.serviceName = mkOption {
            type = types.singleLineStr;
            default = "${name}-queue-short";
            readOnly = true;
          };
          scheduler.serviceName = mkOption {
            type = types.singleLineStr;
            default = "${name}-scheduler";
            readOnly = true;
          };
          websocket.serviceName = mkOption {
            type = types.singleLineStr;
            default = "${name}-websocket";
            readOnly = true;
          };
          envfile-key = mkOption {
            type = types.singleLineStr;
            default = "${name}/frappe_envfile";
            # INIT_ADMIN_PASSWORD=
            # DB_PASSWORD=
          };
        };
        mariadb = {
          image = mkOption {
            type = types.singleLineStr;
            example = "docker.io/mariadb:11.8.8";
          };
          stateDir = mkOption {
            type = types.singleLineStr;
            example = "/var/lib/test/frappe_v16/mariadb_v12";
          };
          envfile-key = mkOption {
            type = types.singleLineStr;
            default = "${name}/mariadb_envfile";
            # MARIADB_ROOT_PASSWORD=
          };
          serviceName = mkOption {
            type = types.singleLineStr;
            default = "${name}-mariadb";
            readOnly = true;
          };
          socket-folder = mkOption {
            type = types.singleLineStr;
            default = "/run/${name}/mariadb";
            readOnly = true;
          };
        };
        valkey = {
          image = mkOption {
            type = types.singleLineStr;
            example = "docker.io/valkey/valkey:8.1.8-alpine";
          };
          stateDir = mkOption {
            type = types.singleLineStr;
            example = "/var/lib/test/frappe_v16/valkey_v8";
          };
          cache = {
            serviceName = mkOption {
              type = types.singleLineStr;
              default = "${name}-valkey-cache";
              readOnly = true;
            };
            socket-folder = mkOption {
              type = types.singleLineStr;
              default = "/run/${name}/valkey-cache";
              readOnly = true;
            };
          };
          queue = {
            stateDir = mkOption {
              type = types.singleLineStr;
              default = "${config.valkey.stateDir}/queue_data";
              readOnly = true;
            };
            serviceName = mkOption {
              type = types.singleLineStr;
              default = "${name}-valkey-queue";
              readOnly = true;
            };
            socket-folder = mkOption {
              type = types.singleLineStr;
              default = "/run/${name}/valkey-queue";
              readOnly = true;
            };
          };
        };
      };
    }));
  };

  config = {
    virtualisation.oci-containers.backend = mkIf (enabled-frappe-compose != {}) "podman";
    virtualisation.podman.defaultNetwork.settings.dns_enabled = mkIf (enabled-frappe-compose != {}) true;
    assertions = mkIf (enabled-frappe-compose != {}) [
      {
        assertion = (config.virtualisation.oci-containers.backend == "podman") && config.virtualisation.podman.defaultNetwork.settings.dns_enabled;
      }
    ];

    sops.secrets = mkMerge (mapAttrsToList (
        name: cfg: {
          ${cfg.frappe.envfile-key} = {};
          ${cfg.mariadb.envfile-key} = {};
        }
      )
      enabled-frappe-compose);

    myOpt.proxy-compose =
      mapAttrs' (name: cfg: (nameValuePair cfg.frappe.frontend.serviceName (mkMerge [
        cfg.proxy-compose
        {
          localMode.port = mkDefault 14144;
          sleep-on-idle = {
            health-check.path = "/api/method/ping";
            endpoints.default.origin = {
              inherit (cfg.frappe.frontend) port listen-address;
            };
            dependsOn =
              (with cfg; [
                mariadb.serviceName
                valkey.cache.serviceName
                valkey.queue.serviceName
              ])
              ++ (with cfg.frappe; [
                build.serviceName
                configurator.serviceName
                create-site.serviceName
                migrate.serviceName
                queue-long.serviceName
                queue-short.serviceName
                scheduler.serviceName
                backend.serviceName
                websocket.serviceName
              ]);
          };
        }
      ])))
      enabled-frappe-compose;

    systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: [
        "d ${cfg.frappe.sitesDir} 700 1000 1000 - -"
        "d ${cfg.frappe.logsDir} 700 1000 1000 - -"
        "d ${cfg.frappe.backend.socket-folder} 700 1000 1000 - -"
        "d ${cfg.mariadb.stateDir} 700 999 999 - -"
        "d ${cfg.mariadb.socket-folder} 777 - - - -" # Because we use passwords
        "d ${cfg.valkey.queue.stateDir} 700 0 0 - -"
        "d ${cfg.valkey.cache.socket-folder} 700 1000 1000 - -"
        "d ${cfg.valkey.queue.socket-folder} 700 1000 1000 - -"
      ])
      enabled-frappe-compose);

    systemd.services = mkMerge (mapAttrsToList (name: cfg: (let
        CONFIGURATOR = "${cfg.frappe.configurator.serviceName}.service";
      in {
        # ${cfg.frappe.migrate.serviceName}.serviceConfig.RemainAfterExit = true;
        # ${cfg.frappe.configurator.serviceName}.serviceConfig.RemainAfterExit = true;
        # ${cfg.frappe.create-site.serviceName}.serviceConfig.RemainAfterExit = true;

        ${cfg.frappe.build.serviceName} = {
          # wantedBy = ["multi-user.target"];
          wants = ["network-online.target"];
          after = ["network-online.target"];
          requiredBy = [CONFIGURATOR];
          before = [CONFIGURATOR];
          environment = {
            GCROOT = cfg.frappe.benchDir;
            APPS_JSON = toString (mkAppsJson name cfg);
            FRAPPE_BRANCH = cfg.frappe.branch;
            BUILD_IMAGE_TAG = cfg.frappe.build.tag;
            BENCH_INIT_SCRIPT = toString bench-init-script;
            BENCH_DIR = cfg.frappe.benchDir;
          };
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart =
              if cfg.frappe.readOnlyMode
              then (getExe (pkgs.writeShellScript "frappe-bench-store-readonly" (builtins.readFile ./bench-readonly.sh)))
              else [frappe-bench-store];
          };
        };
      }))
      enabled-frappe-compose);

    virtualisation.oci-containers.containers = mkMerge (mapAttrsToList (
        name: cfg: let
          valkey_base = {
            inherit autoStart;
            inherit (cfg.valkey) image;
          };
          frappe_base = {
            inherit autoStart;
            inherit (cfg.frappe.base) image;
            environmentFiles = [config.sops.secrets.${cfg.frappe.envfile-key}.path];
            user = "1000:1000";
            workdir = in-container-bench-dir;
            extraOptions = ["--tmpfs" "${in-container-bench-dir}/config:rw,mode=0700,U"];
            volumes = [
              "${cfg.frappe.benchDir}:${in-container-bench-dir}:O"
              "${cfg.frappe.benchDir}${assets-path}:${in-container-bench-dir}${assets-path}:ro"
              "${cfg.frappe.sitesDir}:${in-container-sites-dir}"
              "${cfg.frappe.logsDir}:${in-container-logs-dir}"
              "${cfg.frappe.backend.socket-folder}:${in-container-frappe-socket-folder}"
              "${cfg.mariadb.socket-folder}:${in-container-mariadb-socket-folder}"
              "${cfg.valkey.cache.socket-folder}:${in-container-valkey-cache-socket-folder}"
              "${cfg.valkey.queue.socket-folder}:${in-container-valkey-queue-socket-folder}"
            ];
          };
        in {
          ${cfg.mariadb.serviceName} = {
            inherit autoStart;
            inherit (cfg.mariadb) serviceName image;
            environmentFiles = [config.sops.secrets.${cfg.mariadb.envfile-key}.path];
            environment.MARIADB_AUTO_UPGRADE = "1";
            cmd = [
              "--character-set-server=utf8mb4"
              "--collation-server=utf8mb4_unicode_ci"
              "--skip-character-set-client-handshake"
            ];
            volumes = [
              "${cfg.mariadb.stateDir}:${in-container-mariadb-data-dir}"
              "${cfg.mariadb.socket-folder}:${in-container-mariadb-socket-folder}"
            ];
          };

          ${cfg.valkey.cache.serviceName} = mkMerge [
            valkey_base
            {
              inherit (cfg.valkey.cache) serviceName;
              entrypoint = "sh";
              cmd = [
                "-c"
                "exec redis-server --port 0 --unixsocket ${valkey-cache-socket} --unixsocketperm 777"
              ];
              volumes = [
                "${cfg.valkey.cache.socket-folder}:${in-container-valkey-cache-socket-folder}"
              ];
            }
          ];

          ${cfg.valkey.queue.serviceName} = mkMerge [
            valkey_base
            {
              inherit (cfg.valkey.queue) serviceName;
              entrypoint = "sh";
              cmd = [
                "-c"
                "exec redis-server --port 0 --unixsocket ${valkey-queue-socket} --unixsocketperm 777 --dir ${in-container-valkey-data-dir}"
              ];
              volumes = [
                "${cfg.valkey.queue.stateDir}:${in-container-valkey-data-dir}"
                "${cfg.valkey.queue.socket-folder}:${in-container-valkey-queue-socket-folder}"
              ];
            }
          ];

          ${cfg.frappe.create-site.serviceName} = mkMerge [
            frappe_base
            {
              inherit (cfg.frappe.create-site) serviceName;
              dependsOn = [cfg.frappe.configurator.serviceName];
              entrypoint = "bash";
              environment = {
                SITE = cfg.frappe.siteName;
                MARIADB_SOCKET = mariadb-socket;
                VALKEY_CACHE_SOCKET = valkey-cache-socket;
                VALKEY_QUEUE_SOCKET = valkey-queue-socket;
                READONLY =
                  if cfg.frappe.readOnlyMode
                  then "1"
                  else "0";
              };
              volumes = ["${toString create-site-script}:/opt/create-site.sh:ro"];
              cmd = ["/opt/create-site.sh"];
            }
          ];

          ${cfg.frappe.migrate.serviceName} = let
            enabledApps = attrNames (filterAttrs (_: appCfg: appCfg.enable) cfg.frappe.apps);
          in
            mkMerge [
              frappe_base
              {
                inherit (cfg.frappe.migrate) serviceName;
                dependsOn = [cfg.frappe.create-site.serviceName];
                entrypoint = "bash";
                environment = {
                  SITE = cfg.frappe.siteName;
                  APPS = concatStringsSep " " enabledApps;
                  READONLY =
                    if cfg.frappe.readOnlyMode
                    then "1"
                    else "0";
                };
                volumes = ["${toString migrate-script}:/opt/migrate.sh:ro"];
                cmd = ["/opt/migrate.sh"];
              }
            ];

          ${cfg.frappe.configurator.serviceName} = mkMerge [
            frappe_base
            {
              inherit (cfg.frappe.configurator) serviceName;
              dependsOn = [
                cfg.mariadb.serviceName
                cfg.valkey.cache.serviceName
                cfg.valkey.queue.serviceName
              ];
              entrypoint = "bash";
              environment = {
                MARIADB_SERVICE = cfg.mariadb.serviceName;
                MARIADB_SOCKET = mariadb-socket;
                VALKEY_CACHE_SOCKET = valkey-cache-socket;
                VALKEY_QUEUE_SOCKET = valkey-queue-socket;
                SOCKETIO_PORT = socketio_port;
                MAINTENANCE_MODE =
                  if cfg.frappe.readOnlyMode
                  then "1"
                  else "0";
                ALLOW_READS_DURING_MAINTENANCE =
                  if cfg.frappe.readOnlyMode
                  then "1"
                  else "0";
              };
              volumes = ["${toString configurator-script}:/opt/configurator.sh:ro"];
              cmd = ["/opt/configurator.sh"];
            }
          ];

          ${cfg.frappe.backend.serviceName} = mkMerge [
            frappe_base
            {
              inherit (cfg.frappe.backend) serviceName;
              dependsOn = [cfg.frappe.migrate.serviceName];
              cmd = [
                "/home/frappe/frappe-bench/env/bin/gunicorn"
                "--chdir=${in-container-sites-dir}"
                "--bind"
                "unix:${frappe-socket}"
                "--umask=000"
                "--threads=4"
                "--workers=2"
                "--worker-class=gthread"
                "--worker-tmp-dir=/dev/shm"
                "--timeout=120"
                "--preload"
                "frappe.app:application"
              ];
            }
          ];

          ${cfg.frappe.queue-long.serviceName} = mkMerge [
            frappe_base
            {
              inherit (cfg.frappe.queue-long) serviceName;
              dependsOn = [cfg.frappe.migrate.serviceName];
              cmd = ["bench" "worker" "--queue" "long,default,short"];
            }
          ];

          ${cfg.frappe.queue-short.serviceName} = mkMerge [
            frappe_base
            {
              inherit (cfg.frappe.queue-short) serviceName;
              dependsOn = [cfg.frappe.migrate.serviceName];
              cmd = ["bench" "worker" "--queue" "short,default"];
            }
          ];

          ${cfg.frappe.scheduler.serviceName} = mkMerge [
            frappe_base
            {
              inherit (cfg.frappe.scheduler) serviceName;
              dependsOn = [cfg.frappe.migrate.serviceName];
              cmd = ["bench" "schedule"];
            }
          ];

          ${cfg.frappe.websocket.serviceName} = mkMerge [
            frappe_base
            {
              inherit (cfg.frappe.websocket) serviceName;
              dependsOn = [cfg.frappe.migrate.serviceName];
              cmd = ["node" "/home/frappe/frappe-bench/apps/frappe/socketio.js"];
            }
          ];

          ${cfg.frappe.frontend.serviceName} = mkMerge [
            frappe_base
            {
              inherit (cfg.frappe.frontend) serviceName;
              dependsOn = [
                cfg.frappe.backend.serviceName
                cfg.frappe.websocket.serviceName
              ];
              cmd = ["nginx-entrypoint.sh"];
              environment = {
                BACKEND = "unix:${frappe-socket}";
                FRAPPE_SITE_NAME_HEADER = cfg.frappe.siteName;
                SOCKETIO = "${cfg.frappe.websocket.serviceName}:${socketio_port}";
                UPSTREAM_REAL_IP_ADDRESS = "127.0.0.1";
                UPSTREAM_REAL_IP_HEADER = "X-Forwarded-For";
                UPSTREAM_REAL_IP_RECURSIVE = "off";
                PROXY_READ_TIMEOUT = "120";
                CLIENT_MAX_BODY_SIZE = "50m";
              };
              ports = ["${cfg.frappe.frontend.listen-address}:${toString cfg.frappe.frontend.port}:8080"];
            }
          ];
        }
      )
      enabled-frappe-compose);
  };
}
