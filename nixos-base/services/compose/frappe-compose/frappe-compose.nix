{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.frappe-compose;
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
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        modules = {
          proxy-compose = mkOption {
            type = types.anything;
            default = {};
          };
        };
        networkNamespace = mkOption {
          type = types.anything;
        };
        sliceName = mkOption {
          type = types.anything;
          default = name;
        };
        cgroup-parent = mkOption {
          type = types.anything;
          default = "${sliceName}.slice";
          readOnly = true;
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
            default = cfg.frappe.base.tag; # See https://raw.githubusercontent.com/frappe/frappe_docker/main/docker-bake.hcl
            readOnly = true;
          };
          base = {
            tag = mkOption {
              type = types.singleLineStr;
              example = "v16.25.0";
            };
            image = mkOption {
              type = types.singleLineStr;
              default = "docker.io/frappe/base:${cfg.frappe.base.tag}";
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
              default = cfg.frappe.apps.erpnext.branch; # See https://raw.githubusercontent.com/frappe/frappe_docker/main/docker-bake.hcl
              example = "v16.26.2";
            };
          };
          frontend = {
            containerName = mkOption {
              type = types.singleLineStr;
              default = "${name}-frontend";
              readOnly = true;
            };
            port = mkOption {
              type = types.port;
            };
            host = mkOption {
              type = types.singleLineStr;
              default = "127.0.0.1";
            };
          };
          backend = {
            containerName = mkOption {
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
          configurator.containerName = mkOption {
            type = types.singleLineStr;
            default = "${name}-configurator";
            readOnly = true;
          };
          siteName = mkOption {
            type = types.singleLineStr;
            default = "frontend";
          };
          create-site.containerName = mkOption {
            type = types.singleLineStr;
            default = "${name}-create-site";
            readOnly = true;
          };
          migrate.containerName = mkOption {
            type = types.singleLineStr;
            default = "${name}-migrate";
            readOnly = true;
          };
          queue-long.containerName = mkOption {
            type = types.singleLineStr;
            default = "${name}-queue-long";
            readOnly = true;
          };
          queue-short.containerName = mkOption {
            type = types.singleLineStr;
            default = "${name}-queue-short";
            readOnly = true;
          };
          scheduler.containerName = mkOption {
            type = types.singleLineStr;
            default = "${name}-scheduler";
            readOnly = true;
          };
          websocket.containerName = mkOption {
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
          containerName = mkOption {
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
            containerName = mkOption {
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
              default = "${cfg.valkey.stateDir}/queue_data";
              readOnly = true;
            };
            containerName = mkOption {
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

  config = mkIf (enabled != {}) {
    virtualisation.oci-containers.backend = "podman";
    virtualisation.podman.defaultNetwork.settings.dns_enabled = true;

    sops.secrets = mkMerge (mapAttrsToList (
        name: cfg: {
          ${cfg.frappe.envfile-key} = {};
          ${cfg.mariadb.envfile-key} = {};
        }
      )
      enabled);

    myOpt.proxy-compose =
      mapAttrs' (name: cfg: (nameValuePair name (mkMerge [
        cfg.modules.proxy-compose
        {
          enable = true;
          modules = {
            sleep-on-idle = {
              inherit (cfg) sliceName;
              health-check.path = "/api/method/ping";
              endpoints.default.origin = {
                inherit (cfg.frappe.frontend) port host;
              };
              sleep.systemd-services = with cfg.frappe; [
                build.serviceName
              ];
              sleep.oci-containers =
                (with cfg; [
                  mariadb.containerName
                  valkey.cache.containerName
                  valkey.queue.containerName
                ])
                ++ (with cfg.frappe; [
                  frontend.containerName
                  configurator.containerName
                  create-site.containerName
                  migrate.containerName
                  queue-long.containerName
                  queue-short.containerName
                  scheduler.containerName
                  backend.containerName
                  websocket.containerName
                ]);
            };
          };
        }
      ])))
      enabled;

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
      enabled);

    systemd.services = mkMerge (mapAttrsToList (name: cfg: (let
        CONFIGURATOR = "${cfg.frappe.configurator.serviceName}.service";
      in {
        ${cfg.frappe.build.serviceName} = {
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
      enabled);

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
          ${cfg.mariadb.containerName} = {
            inherit autoStart;
            inherit (cfg.mariadb) serviceName image;
            environmentFiles = [config.sops.secrets.${cfg.mariadb.envfile-key}.path];
            volumes = [
              "${cfg.mariadb.stateDir}:${in-container-mariadb-data-dir}"
              "${cfg.mariadb.socket-folder}:${in-container-mariadb-socket-folder}"
            ];
          };

          ${cfg.valkey.cache.containerName} = mkMerge [
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

          ${cfg.valkey.queue.containerName} = mkMerge [
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

          ${cfg.frappe.create-site.containerName} = mkMerge [
            frappe_base
            {
              inherit (cfg.frappe.create-site) serviceName;
              dependsOn = [cfg.frappe.configurator.containerName];
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

          ${cfg.frappe.migrate.containerName} = let
            enabledApps = attrNames (filterAttrs (_: appCfg: appCfg.enable) cfg.frappe.apps);
          in
            mkMerge [
              frappe_base
              {
                inherit (cfg.frappe.migrate) serviceName;
                dependsOn = [cfg.frappe.create-site.containerName];
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

          ${cfg.frappe.configurator.containerName} = mkMerge [
            frappe_base
            {
              inherit (cfg.frappe.configurator) serviceName;
              dependsOn = [
                cfg.mariadb.containerName
                cfg.valkey.cache.containerName
                cfg.valkey.queue.containerName
              ];
              entrypoint = "bash";
              environment = {
                MARIADB_SERVICE = cfg.mariadb.containerName;
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

          ${cfg.frappe.backend.containerName} = mkMerge [
            frappe_base
            {
              inherit (cfg.frappe.backend) serviceName;
              dependsOn = [cfg.frappe.migrate.containerName];
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

          ${cfg.frappe.queue-long.containerName} = mkMerge [
            frappe_base
            {
              inherit (cfg.frappe.queue-long) serviceName;
              dependsOn = [cfg.frappe.migrate.containerName];
              cmd = ["bench" "worker" "--queue" "long,default,short"];
            }
          ];

          ${cfg.frappe.queue-short.containerName} = mkMerge [
            frappe_base
            {
              inherit (cfg.frappe.queue-short) serviceName;
              dependsOn = [cfg.frappe.migrate.containerName];
              cmd = ["bench" "worker" "--queue" "short,default"];
            }
          ];

          ${cfg.frappe.scheduler.containerName} = mkMerge [
            frappe_base
            {
              inherit (cfg.frappe.scheduler) serviceName;
              dependsOn = [cfg.frappe.migrate.containerName];
              cmd = ["bench" "schedule"];
            }
          ];

          ${cfg.frappe.websocket.containerName} = mkMerge [
            frappe_base
            {
              inherit (cfg.frappe.websocket) serviceName;
              dependsOn = [cfg.frappe.migrate.containerName];
              cmd = ["node" "/home/frappe/frappe-bench/apps/frappe/socketio.js"];
            }
          ];

          ${cfg.frappe.frontend.containerName} = mkMerge [
            frappe_base
            {
              inherit (cfg.frappe.frontend) serviceName;
              dependsOn = [
                cfg.frappe.backend.containerName
                cfg.frappe.websocket.containerName
              ];
              cmd = ["nginx-entrypoint.sh"];
              environment = {
                BACKEND = "unix:${frappe-socket}";
                FRAPPE_SITE_NAME_HEADER = cfg.frappe.siteName;
                SOCKETIO = "${cfg.frappe.websocket.containerName}:${socketio_port}";
                UPSTREAM_REAL_IP_ADDRESS = "127.0.0.1";
                UPSTREAM_REAL_IP_HEADER = "X-Forwarded-For";
                UPSTREAM_REAL_IP_RECURSIVE = "off";
                PROXY_READ_TIMEOUT = "120";
                CLIENT_MAX_BODY_SIZE = "50m";
              };
              ports = ["${cfg.frappe.frontend.host}:${toString cfg.frappe.frontend.port}:8080"];
            }
          ];
        }
      )
      enabled);
  };
}
