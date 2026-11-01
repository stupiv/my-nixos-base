{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (name: cfg: cfg.enable) outerCfg.myOpt.keycloak-compose;
in {
  options.myOpt.keycloak-compose = mkOption {
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
          keycloak = mkOption {
            type = types.anything;
            default = {};
          };
          postgresql = mkOption {
            type = types.anything;
            default = {};
          };
          proxy-compose = mkOption {
            type = types.anything;
            default = {};
          };
        };
        container = {
          name = mkOption {
            type = types.singleLineStr;
            default = name;
          };
          stateDir = mkOption {
            type = types.singleLineStr;
          };
          shared-run-dir = mkOption {
            type = types.singleLineStr;
            default = "/run/keycloak-compose/${name}";
          };
        };
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "container@${cfg.container.name}";
          readOnly = true;
        };
        database.port = mkOption {
          type = types.port;
          default = 15447;
        };
        proxy-compose-id = mkOption {
          type = types.singleLineStr;
          default = name;
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    myOpt.proxy-compose = mapAttrs' (name: cfg:
      nameValuePair cfg.proxy-compose-id (mkMerge [
        cfg.modules.proxy-compose
        {
          enable = true;
          modules.sleep-on-idle = {
            health-check.path = "/";
            endpoints.default.origin.ip-socket = outerCfg.myOpt.keycloak.${name}.unix-socket;
            set-cgroup-parent.systemd-services = [cfg.serviceName];
            set-cgroup-parent.oci-containers = [];
          };
        }
      ]))
    enabled;

    myOpt.keycloak = mapAttrs' (name: cfg: let
      inherit (outerCfg.myOpt.proxy-compose.${cfg.proxy-compose-id}) localMode hostname;
    in
      nameValuePair name (mkMerge [
        cfg.modules.keycloak
        {
          inherit (cfg) container;
          enable = true;
          modules.services.keycloak = {
            plugins = with cfg.modules.keycloak.modules.services.keycloak.package.plugins; [
              junixsocket-common
              junixsocket-native-common
            ];
            database = {
              inherit (cfg.database) port;
              type = "postgresql";
              createLocally = false;
              host = "/run/postgresql";
            };
            settings = {
              hostname = (
                if (localMode.enable)
                then "http://${localMode.ip-socket}"
                else "https://${hostname}"
              );
            };
          };
        }
      ]))
    enabled;

    myOpt.postgresql = mapAttrs' (name: cfg:
      nameValuePair name (mkMerge [
        cfg.modules.postgresql
        {
          inherit (cfg) container;
          enable = true;
          modules.services.postgresql = {
            settings = {
              inherit (cfg.database) port;
            };
            ensureDatabases = ["keycloak"];
            ensureUsers = [
              {
                name = "keycloak";
                ensureDBOwnership = true;
              }
            ];
          };
        }
      ]))
    enabled;

    systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: [
        "d '${cfg.container.stateDir}' 0711 root root - -"
        "d '${cfg.container.shared-run-dir}' 0711 root root - -"
      ])
      enabled);

    containers = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.container.name} = {
          ephemeral = true;
          autoStart = false;
          config.nixpkgs.pkgs = pkgs;
          privateNetwork = true;
          privateUsers = "pick";
          extraFlags = [
            "--bind=${cfg.container.stateDir}:${cfg.container.stateDir}:idmap"
            "--bind=${cfg.container.shared-run-dir}:${cfg.container.shared-run-dir}:rootidmap"
          ];
        };
      })
      enabled);
  };
}
