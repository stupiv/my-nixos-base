{
  config,
  lib,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.keycloak;
in {
  options.myOpt.keycloak = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        container = mkOption {
          type = types.anything;
          default = {};
        };
        unix-socket = mkOption {
          type = types.singleLineStr;
          default = "${cfg.container.shared-run-dir}/keycloak.sock";
          readOnly = true;
        };
        keycloak = mkOption {
          type = types.anything;
          default = {};
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    containers = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.container.name} = {
          config = {config, ...} @ innerArgs: let
            innerCfg = innerArgs.config;
          in {
            imports = [
              ./systemd-socket-proxyd.nix
            ];

            myOpt.systemd-socket-proxyd.${name} = {
              origin = {
                host = innerCfg.services.keycloak.settings.http-host;
                port = innerCfg.services.keycloak.settings.http-port;
                serviceName = "keycloak";
              };
              proxy.ip-socket = cfg.unix-socket;
            };
            services.keycloak = mkMerge [
              cfg.keycloak
              {
                enable = true;
                package = mkDefault cfg.keycloak.package;
                database = {
                  inherit (cfg.keycloak.database) type host createLocally;
                };
                settings = {
                  inherit (cfg.keycloak.settings) hostname;
                  http-host = mkDefault "::1";
                  http-port = mkDefault 25546;
                  http-enabled = mkDefault true;
                  proxy-headers = mkDefault "xforwarded";
                };
              }
            ];
          };
        };
      })
      enabled);
  };
}
