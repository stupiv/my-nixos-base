{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.cdp-compose;
in {
  options.myOpt.cdp-compose = mkOption {
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
          sleep-on-idle = mkOption {
            type = types.anything;
            default = {};
          };
          cdp = mkOption {
            type = types.anything;
            default = {};
          };
        };
        sleep-on-idle-id = mkOption {
          type = types.singleLineStr;
          default = name;
        };
        netns-id = mkOption {
          type = types.nullOr types.singleLineStr;
          default = null;
        };
        cdp-id = mkOption {
          type = types.singleLineStr;
          default = name;
        };
        cdp-cfg = mkOption {
          type = types.anything;
          default = outerCfg.myOpt.cdp.${cfg.cdp-id};
          readOnly = true;
        };
        sleep-on-idle-cfg = mkOption {
          type = types.anything;
          default = outerCfg.myOpt.sleep-on-idle.${cfg.sleep-on-idle-id};
          readOnly = true;
        };
        url = mkOption {
          type = types.strMatching "^ws://[^/]+:[0-9]+$";
          default = "ws://${pkgs.myLib.bracketIpv6 cfg.sleep-on-idle-cfg.endpoints.default.proxy.ip-socket}";
          readOnly = true;
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.sleep-on-idle-id} = mkMerge [
          cfg.modules.sleep-on-idle
          {
            enable = true;
            health-check.path = "/";
            endpoints.default = {
              origin = {
                inherit (cfg.cdp-cfg) host port;
              };
              proxy = {
                inherit (cfg.modules.sleep-on-idle.endpoints.default.proxy) port;
                inherit (cfg) netns-id;
              };
            };
            set-cgroup-parent = {
              oci-containers = [];
              nixos-containers = [];
            };
          }
        ];
      })
      enabled);

    myOpt.cdp = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.cdp-id} = mkMerge [
          cfg.modules.cdp
          {
            enable = true;
            inherit (cfg) sleep-on-idle-id netns-id;
          }
        ];
      })
      enabled);
  };
}
