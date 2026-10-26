{
  config,
  lib,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.keycloak-compose;
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
      };
    }));
  };

  config = mkIf (enabled != {}) {
    myOpt.proxy-compose = mapAttrs' (_: cfg:
      nameValuePair cfg.serviceName (mkMerge [
        cfg.modules.proxy-compose
        {
          localMode.port = mkDefault 33553;
          sleep-on-idle = {
            health-check.path = "/";
            endpoints.default.origin.ip-socket = outerCfg.myOpt.keycloak.unix-socket;
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
        }
      ]))
    enabled;

    myOpt.keycloak = mapAttrs' (name: cfg:
      nameValuePair name (mkMerge [
        cfg.modules.keycloak
        {
          inherit (cfg) container;
          enable = true;
          keycloak = {
            database = {
              type = "postgresql";
              host = "/run/postgresql";
              createLocally = true;
            };
            settings = {
              hostname = cfg.modules.proxy-compose.hostname;
            };
          };
        }
      ]))
    enabled;

    systemd.tmpfiles.rules = flatten (mapAttrsToList (_: cfg: [
        "d '${cfg.stateDir}' 0700 - - - -"
        "d '${cfg.shared-run-dir}' 0700 - - - -"
      ])
      enabled);

    containers = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.container.name} = {
          ephemeral = true;
          privateNetwork = true;
          privateUsers = "pick";
          autoStart = false;
          bindMounts = {
            ${cfg.stateDir} = {
              hostPath = cfg.stateDir;
              isReadOnly = false;
            };
            ${cfg.shared-run-dir} = {
              hostPath = cfg.shared-run-dir;
              isReadOnly = false;
            };
          };
        };
      })
      enabled);
  };
}
