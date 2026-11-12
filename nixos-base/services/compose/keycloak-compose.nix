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
          # stateDir = mkOption {
          #   type = types.singleLineStr;
          # };
          # shared-run-dir = mkOption {
          #   type = types.singleLineStr;
          #   default = "/run/keycloak-compose/${name}";
          # };
        };
        database.port = mkOption {
          type = types.port;
        };
        proxy-compose-id = mkOption {
          type = types.singleLineStr;
          default = name;
        };
        keycloak-id = mkOption {
          type = types.singleLineStr;
          default = name;
        };
        sleep-on-idle-id = mkOption {
          type = types.singleLineStr;
          default = name;
        };
        sleep-on-idle-cfg = mkOption {
          type = types.anything;
          default = outerCfg.myOpt.sleep-on-idle.${cfg.sleep-on-idle-id};
          readOnly = true;
        };
        netns-id = mkOption {
          type = types.singleLineStr;
          default = name;
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    myOpt.netns = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.netns-id}.set-network-namespace = {
          # systemd-services = [
          #   cfg.sleep-on-idle-cfg.endpoints.default.proxy.serviceName
          # ];
          systemd-services = [];
          oci-containers = [];
          nixos-containers = [cfg.container.name];
        };
      })
      enabled);

    myOpt.proxy-compose = mapAttrs' (name: cfg:
      nameValuePair cfg.proxy-compose-id (mkMerge [
        cfg.modules.proxy-compose
        {
          inherit (cfg) sleep-on-idle-id;
          enable = true;
          modules.sleep-on-idle = {
            health-check.path = "/";
            endpoints.default = {
              origin = {
                inherit (outerCfg.myOpt.keycloak.${cfg.keycloak-id}) host port;
              };
              proxy = {
                inherit (cfg) netns-id;
              };
            };
            # endpoints.default.origin.ip-socket = outerCfg.myOpt.keycloak.${name}.unix-socket;
            set-cgroup-parent.systemd-services = [];
            set-cgroup-parent.oci-containers = [];
            set-cgroup-parent.nixos-containers = [cfg.container.name];
          };
        }
      ]))
    enabled;

    # systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: [
    #     "d '${cfg.container.stateDir}' 0711 root root - -"
    #     "d '${cfg.container.shared-run-dir}' 0711 root root - -"
    #   ])
    #   enabled);

    containers = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.container.name} = {
          ephemeral = true;
          autoStart = false;
          privateUsers = "pick";
          config.nixpkgs.pkgs = pkgs;
          # privateNetwork = true;
          # extraFlags = [
          #   "--bind=${cfg.container.stateDir}:${cfg.container.stateDir}:idmap"
          #   "--bind=${cfg.container.shared-run-dir}:${cfg.container.shared-run-dir}:rootidmap"
          # ];
        };
      })
      enabled);

    myOpt.keycloak = mapAttrs' (name: cfg: let
      inherit (outerCfg.myOpt.proxy-compose.${cfg.proxy-compose-id}) localMode hostname;
    in
      nameValuePair cfg.keycloak-id (mkMerge [
        cfg.modules.keycloak
        {
          inherit (cfg) sleep-on-idle-id netns-id;
          enable = true;
          container.name = cfg.container.name;
          modules.services.keycloak = {
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
          inherit (cfg) sleep-on-idle-id netns-id;
          enable = true;
          container.name = cfg.container.name;
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
  };
}
