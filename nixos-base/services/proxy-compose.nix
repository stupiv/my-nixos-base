{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.proxy-compose;
in {
  options.myOpt.proxy-compose = mkOption {
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
          cloudflared = mkOption {
            type = types.anything;
            default = {};
          };
          caddy = mkOption {
            type = types.anything;
            default = {};
          };
          sleep-on-idle = mkOption {
            type = types.anything;
          };
        };
        cloudflared = {
          enable = mkOption {
            type = types.bool;
            default = cfg.modules.cloudflared != {};
            readOnly = true;
          };
          unix-socket = mkOption {
            type = types.strMatching "^/run/.*\.sock$";
            default = "/run/${name}/proxy-compose/caddy-to-cloudflared.sock";
          };
        };
        caddy = {
          enable = mkOption {
            type = types.bool;
            default = cfg.modules.caddy != {};
            readOnly = true;
          };
        };
        hostname = mkOption {
          type = types.singleLineStr;
        };
        sleep-on-idle-id = mkOption {
          type = types.singleLineStr;
        };
        sleep-on-idle-cfg = mkOption {
          type = types.anything;
          default = outerCfg.myOpt.sleep-on-idle.${cfg.sleep-on-idle-id};
          readOnly = true;
        };
        default-unix-socket = mkOption {
          type = types.strMatching "^/run/.*\.sock$";
          default = cfg.sleep-on-idle-cfg.endpoints.default.proxy.ip-socket;
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
          }
        ];
      })
      enabled);

    myOpt.cloudflared = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.modules.cloudflared.tunnel-id} = mkMerge [
          cfg.modules.cloudflared
          {
            enable = true;
            tunnelCfg.ingress = {
              ${cfg.hostname} =
                if (cfg.caddy.enable)
                then "unix:${cfg.cloudflared.unix-socket}"
                else "unix:${cfg.default-unix-socket}";
            };
          }
        ];
      })
      (filterAttrs (_: cfg: cfg.cloudflared.enable) enabled));

    myOpt.caddy = mkMerge (mapAttrsToList (name: cfg: {
        ${name} = mkMerge [
          cfg.modules.caddy
          {
            enable = true;
            inherit (cfg) sleep-on-idle-id hostname;
            local.unix.socket = mkIf (cfg.cloudflared.enable) cfg.cloudflared.unix-socket;
          }
        ];
      })
      (filterAttrs (_: cfg: cfg.caddy.enable) enabled));
  };
}
