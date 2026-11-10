{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
in {
  options.myOpt.frappe-v16-compose = mkOption {
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
          squid = mkOption {
            type = types.anything;
            default = {};
          };
        };
        proxy-compose-id = mkOption {
          type = types.anything;
          default = name;
        };
        sleep-on-idle-id = mkOption {
          type = types.anything;
          default = outerCfg.myOpt.proxy-compose.${cfg.proxy-compose-id}.sleep-on-idle-id;
          readOnly = true;
        };
        netns-id = mkOption {
          type = types.anything;
          default = name;
        };
        sopsFile = mkOption {
          type = types.anything;
          default = name;
        };
        frappe = {
          readOnlyMode = mkOption {
            type = types.bool;
            default = false;
          };
          stateDir = mkOption {
            type = types.strMatching "^\/var\/lib\/.+[^\/]$";
            example = "/var/lib/${name}/frappe";
          };
          sitesPath = mkOption {
            type = types.strMatching "^\/.+[^\/]$";
            example = "/sites";
          };
          logsPath = mkOption {
            type = types.strMatching "^\/.+[^\/]$";
            example = "/logs";
          };
          sitesDir = mkOption {
            type = types.singleLineStr;
            default = "${cfg.frappe.stateDir}${cfg.frappe.sitesPath}";
            readOnly = true;
          };
          logsDir = mkOption {
            type = types.singleLineStr;
            default = "${cfg.frappe.stateDir}${cfg.frappe.logsPath}";
            readOnly = true;
          };
          benchDir = mkOption {
            type = types.singleLineStr;
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
              type = types.strMatching "^v16\.[0-9]+\.[0-9]+$";
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
            };
            tag = mkOption {
              type = types.strMatching "^v16\.[0-9]+\.[0-9]+$";
              default = cfg.frappe.apps.erpnext.branch; # See https://raw.githubusercontent.com/frappe/frappe_docker/main/docker-bake.hcl
            };
          };
          frontend.containerName = mkOption {
            type = types.singleLineStr;
            default = "${name}-frontend";
          };
          backend = {
            containerName = mkOption {
              type = types.singleLineStr;
              default = "${name}-backend";
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
          };
          siteName = mkOption {
            type = types.singleLineStr;
          };
          create-site.containerName = mkOption {
            type = types.singleLineStr;
            default = "${name}-create-site";
          };
          migrate.containerName = mkOption {
            type = types.singleLineStr;
            default = "${name}-migrate";
          };
          queue-long.containerName = mkOption {
            type = types.singleLineStr;
            default = "${name}-queue-long";
          };
          queue-short.containerName = mkOption {
            type = types.singleLineStr;
            default = "${name}-queue-short";
          };
          scheduler.containerName = mkOption {
            type = types.singleLineStr;
            default = "${name}-scheduler";
          };
          websocket.containerName = mkOption {
            type = types.singleLineStr;
            default = "${name}-websocket";
          };
          envFile-key = mkOption {
            type = types.singleLineStr;
            default = "${name}/frappe_envFile";
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
            example = "/var/lib/${name}/mariadb";
          };
          envFile-key = mkOption {
            type = types.singleLineStr;
            default = "${name}/mariadb_envFile";
            # MARIADB_ROOT_PASSWORD=
          };
          containerName = mkOption {
            type = types.singleLineStr;
            default = "${name}-mariadb";
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
            example = "/var/lib/${name}/valkey";
          };
          cache = {
            containerName = mkOption {
              type = types.singleLineStr;
              default = "${name}-valkey-cache";
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
}
