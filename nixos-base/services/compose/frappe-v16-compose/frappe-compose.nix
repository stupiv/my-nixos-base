{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.frappe-v16-compose;

  in-container-bench-dir = "/home/frappe/frappe-bench";
  assets-path = "/sites/assets";
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
  frappe-frontend-proxy-name = name: "${name}-frappe-frontend";
  frappe-container-names = cfg: with cfg; [
    mariadb.containerName
    valkey.cache.containerName
    valkey.queue.containerName
    frappe.frontend.containerName
    frappe.configurator.containerName
    frappe.create-site.containerName
    frappe.migrate.containerName
    frappe.queue-long.containerName
    frappe.queue-short.containerName
    frappe.scheduler.containerName
    frappe.backend.containerName
    frappe.websocket.containerName
  ];
  in-container-sites-dir = "${in-container-bench-dir}/sites";
  in-container-logs-dir = "${in-container-bench-dir}/logs";
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

  bench-init-script = pkgs.writeScript "bench-init.sh" (builtins.readFile ./bench-init.sh);
  create-site-script = pkgs.writeScript "create-site.sh" (builtins.readFile ./create-site.sh);
  migrate-script = pkgs.writeScript "migrate.sh" (builtins.readFile ./migrate.sh);
  configurator-script = pkgs.writeScript "configurator.sh" (builtins.readFile ./configurator.sh);
in {
  config = mkIf (enabled != {}) {
    virtualisation.oci-containers.backend = "podman";

    myOpt.netns = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.networkNamespace}.set-network-namespace = {
          oci-containers = frappe-container-names cfg;
          systemd-services = [
            outerCfg.myOpt.systemd-socket-proxyd.${frappe-frontend-proxy-name name}.proxy.serviceName
          ];
        };
      })
      enabled);

    sops.secrets = mkMerge (mapAttrsToList (
        name: cfg: {
          ${cfg.frappe.envfile-key} = {};
          ${cfg.mariadb.envfile-key} = {};
        }
      )
      enabled);

    myOpt.proxy-compose =
      mapAttrs' (name: cfg: (nameValuePair cfg.proxy-compose-id (mkMerge [
        cfg.modules.proxy-compose
        {
          enable = true;
          modules = {
            sleep-on-idle = {
              health-check.path = "/api/method/ping";
              endpoints.default.origin = {
                inherit (cfg.frappe.frontend) port host;
              };
              set-cgroup-parent.systemd-services = with cfg.frappe; [
                build.serviceName
              ];
              set-cgroup-parent.oci-containers = frappe-container-names cfg;
            };
          };
        }
      ])))
      enabled;

    myOpt.systemd-socket-proxyd = mkMerge (mapAttrsToList (name: cfg: {
        "${frappe-frontend-proxy-name name}" = {
          origin = {
            host = "127.0.0.1";
            port = 8080;
            serviceName = outerCfg.virtualisation.oci-containers.containers.${cfg.frappe.frontend.containerName}.serviceName;
          };
          proxy = {
            inherit (cfg.frappe.frontend) host port;
          };
        };
      })
      enabled);

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
        configuratorUnit = "${outerCfg.virtualisation.oci-containers.containers.${cfg.frappe.configurator.containerName}.serviceName}.service";
      in {
        ${cfg.frappe.build.serviceName} = {
          wants = ["network-online.target"];
          after = ["network-online.target"];
          requiredBy = [configuratorUnit];
          before = [configuratorUnit];
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
            autoStart = false;
            inherit (cfg.valkey) image;
          };
          frappe_base = {
            autoStart = false;
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
            autoStart = false;
            inherit (cfg.mariadb) image;
            environmentFiles = [config.sops.secrets.${cfg.mariadb.envfile-key}.path];
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

          ${cfg.valkey.cache.containerName} = mkMerge [
            valkey_base
            {
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
              dependsOn = [
                cfg.mariadb.containerName
                cfg.valkey.cache.containerName
                cfg.valkey.queue.containerName
              ];
              entrypoint = "bash";
              environment = {
                MARIADB_SERVICE = "localhost";
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
              dependsOn = [cfg.frappe.migrate.containerName];
              cmd = ["bench" "worker" "--queue" "long,default,short"];
            }
          ];

          ${cfg.frappe.queue-short.containerName} = mkMerge [
            frappe_base
            {
              dependsOn = [cfg.frappe.migrate.containerName];
              cmd = ["bench" "worker" "--queue" "short,default"];
            }
          ];

          ${cfg.frappe.scheduler.containerName} = mkMerge [
            frappe_base
            {
              dependsOn = [cfg.frappe.migrate.containerName];
              cmd = ["bench" "schedule"];
            }
          ];

          ${cfg.frappe.websocket.containerName} = mkMerge [
            frappe_base
            {
              dependsOn = [cfg.frappe.migrate.containerName];
              cmd = ["node" "/home/frappe/frappe-bench/apps/frappe/socketio.js"];
            }
          ];

          ${cfg.frappe.frontend.containerName} = mkMerge [
            frappe_base
            {
              dependsOn = [
                cfg.frappe.backend.containerName
                cfg.frappe.websocket.containerName
              ];
              cmd = ["nginx-entrypoint.sh"];
              environment = {
                BACKEND = "unix:${frappe-socket}";
                FRAPPE_SITE_NAME_HEADER = cfg.frappe.siteName;
                SOCKETIO = "127.0.0.1:${socketio_port}";
                UPSTREAM_REAL_IP_ADDRESS = "127.0.0.1";
                UPSTREAM_REAL_IP_HEADER = "X-Forwarded-For";
                UPSTREAM_REAL_IP_RECURSIVE = "off";
                PROXY_READ_TIMEOUT = "120";
                CLIENT_MAX_BODY_SIZE = "50m";
              };
            }
          ];
        }
      )
      enabled);
  };
}
