{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.camofox-browser-compose;
in {
  options.myOpt.camofox-browser-compose = mkOption {
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
          camofox-browser = mkOption {
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
        camofox-browser-id = mkOption {
          type = types.singleLineStr;
          default = name;
        };
        camofox-browser-cfg = mkOption {
          type = types.anything;
          default = outerCfg.myOpt.camofox-browser.${cfg.camofox-browser-id};
          readOnly = true;
        };
        sleep-on-idle-cfg = mkOption {
          type = types.anything;
          default = outerCfg.myOpt.sleep-on-idle.${cfg.sleep-on-idle-id};
          readOnly = true;
        };
        CAMOFOX_URL = mkOption {
          type = types.strMatching "^http://[^/]+:[0-9]+$";
          default = "http://${pkgs.myLib.bracketIpv6 cfg.sleep-on-idle-cfg.endpoints.default.proxy.ip-socket}";
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
                inherit (cfg.camofox-browser-cfg) host port;
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

    myOpt.camofox-browser = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.camofox-browser-id} = mkMerge [
          cfg.modules.camofox-browser
          {
            enable = true;
            inherit (cfg) sleep-on-idle-id netns-id;
          }
        ];
      })
      enabled);
  };
}
