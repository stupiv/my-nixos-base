{
  config,
  lib,
  pkgs,
  utils,
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
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart =
              if cfg.frappe.readOnlyMode
              then
                (getExe (pkgs.writeShellScript "frappe-bench-store-readonly" ''
                  if [ -e ${escapeShellArg cfg.frappe.benchDir} ]; then
                    echo "WARNING: read-only mode; skipping frappe-bench rebuild." >&2
                    echo "Changes to apps/branches will not take effect until read-only mode is disabled." >&2
                    exit 0
                  fi
                  echo "ERROR: read-only mode is enabled but no frappe-bench exists at ${escapeShellArg cfg.frappe.benchDir}." >&2
                  echo "A read-only deployment needs an existing bench; disable read-only mode" >&2
                  echo "for the first deployment, then re-enable it." >&2
                  exit 1
                ''))
              else
                utils.escapeSystemdExecArgs [
                  frappe-bench-store
                  "--gcroot"
                  cfg.frappe.benchDir
                  "--apps-json"
                  (mkAppsJson name cfg)
                  "--frappe-branch"
                  cfg.frappe.branch
                  "--build-image-tag"
                  cfg.frappe.build.tag
                ];
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

          ${cfg.frappe.create-site.serviceName} = let
            site = cfg.frappe.siteName;
          in
            mkMerge [
              frappe_base
              {
                inherit (cfg.frappe.create-site) serviceName;
                dependsOn = [cfg.frappe.configurator.serviceName];
                entrypoint = "bash";
                cmd = [
                  "-c"
                  ''
                    set -e
                    until [ -S "${mariadb-socket}" ] && \
                          [ -S "${valkey-cache-socket}" ] && \
                          [ -S "${valkey-queue-socket}" ]; do
                      echo "Waiting for unix sockets..."
                      sleep 5
                    done
                    export start=$(date +%s);
                    until [[ -n `grep -hs ^ sites/common_site_config.json | jq -r ".db_socket // empty"` ]] && \
                      [[ -n `grep -hs ^ sites/common_site_config.json | jq -r ".redis_cache // empty"` ]] && \
                      [[ -n `grep -hs ^ sites/common_site_config.json | jq -r ".redis_queue // empty"` ]];
                    do
                      echo "Waiting for sites/common_site_config.json to be created";
                      sleep 5;
                      if (( $(date +%s)-start > 120 )); then
                        echo "could not find sites/common_site_config.json with required keys";
                        exit 1
                      fi
                    done;
                    echo "sites/common_site_config.json found";
                    if [ -f "sites/${site}/.site-created" ]; then
                      echo "Site ${site} already created; nothing to do";
                    ${optionalString cfg.frappe.readOnlyMode ''
                      elif true; then
                        echo "ERROR: readOnlyMode is enabled but site ${site} does not exist yet." >&2;
                        echo "Refusing to create a new site in read-only mode; disable readOnlyMode first." >&2;
                        exit 1;
                    ''}
                    elif [ -d "sites/${site}" ]; then
                      echo "ERROR: sites/${site} exists but has no .site-created marker." >&2;
                      echo "A previous 'bench new-site' probably failed halfway, or the site" >&2;
                      echo "predates the marker convention. Refusing to touch it." >&2;
                      echo "" >&2;
                      echo "Fix manually, then restart this service:" >&2;
                      echo "  - if the site is healthy:  touch sites/${site}/.site-created" >&2;
                      echo "  - if it is half-created:   bench drop-site ${site} --db-root-username=root --db-root-password=... --force --no-backup" >&2;
                      exit 1;
                    else
                      bench new-site --mariadb-user-host-login-scope='%' --db-root-username=root \
                      --admin-password="$INIT_ADMIN_PASSWORD" \
                      --db-root-password="$DB_PASSWORD" \
                      --set-default ${site};
                      touch sites/${site}/.site-created;
                    fi
                  ''
                ];
              }
            ];

          ${cfg.frappe.migrate.serviceName} = let
            site = cfg.frappe.siteName;
            enabledApps = attrNames (filterAttrs (_: appCfg: appCfg.enable) cfg.frappe.apps);
          in
            mkMerge [
              frappe_base
              {
                inherit (cfg.frappe.migrate) serviceName;
                dependsOn = [cfg.frappe.create-site.serviceName];
                entrypoint = "bash";
                cmd = [
                  "-c"
                  ''
                    set -e
                    ${optionalString cfg.frappe.readOnlyMode ''
                      echo "readOnlyMode is enabled; skipping app sync and migrate.";
                      exit 0;
                    ''}
                    export start=$(date +%s);
                    until [ -f "sites/${site}/.site-created" ]; do
                      echo "Waiting for site ${site} to be created...";
                      sleep 5;
                      if (( $(date +%s)-start > 600 )); then
                        echo "site ${site} was not created in time" >&2;
                        exit 1;
                      fi
                    done;
                    installed=$(bench --site ${site} list-apps -f json | jq -r '."${site}"[]');
                    for app in ${escapeShellArgs enabledApps}; do
                      if ! grep -qx "$app" <<< "$installed"; then
                        echo "Installing new app: $app";
                        bench --site ${site} install-app "$app";
                      fi
                    done;
                    for app in $installed; do
                      if [ "$app" != "frappe" ] && ! grep -qx "$app" <<< ${escapeShellArg (concatStringsSep "\n" enabledApps)}; then
                        echo "WARNING: app '$app' is installed on site ${site} but not enabled in configuration." >&2;
                        echo "Uninstalling apps is destructive (drops their DocTypes and data), so it is left to you:" >&2;
                        echo "  bench --site ${site} uninstall-app $app" >&2;
                      fi
                    done;
                    echo "Running migrate for site ${site}";
                    bench --site ${site} migrate;
                  ''
                ];
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
              cmd = [
                "-c"
                ''
                  if [ ! -f sites/common_site_config.json ]; then
                    echo "{}" > sites/common_site_config.json;
                  fi;
                  ls -1 apps > sites/apps.txt;
                  bench set-config -g db_type mariadb;
                  bench set-config -g db_host ${escapeShellArg cfg.mariadb.serviceName};
                  bench set-config -g db_socket "${mariadb-socket}";
                  bench set-config -g redis_cache "unix://${valkey-cache-socket}";
                  bench set-config -g redis_queue "unix://${valkey-queue-socket}";
                  bench set-config -g redis_socketio "unix://${valkey-queue-socket}";
                  bench set-config -gp socketio_port "${socketio_port}";
                  bench set-config -gp maintenance_mode ${
                    if cfg.frappe.readOnlyMode
                    then "1"
                    else "0"
                  };
                  bench set-config -gp allow_reads_during_maintenance ${
                    if cfg.frappe.readOnlyMode
                    then "1"
                    else "0"
                  };
                ''
              ];
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
