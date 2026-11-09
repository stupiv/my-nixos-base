{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.litellm;
in {
  options.myOpt.litellm = mkOption {
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
          services.litellm = mkOption {
            type = types.anything;
            default = {};
          };
        };
        netns-id = mkOption {
          type = types.singleLineStr;
        };
        sleep-on-idle-id = mkOption {
          type = types.singleLineStr;
        };
        container = mkOption {
          type = types.anything;
          default = {};
        };
        stateDir = mkOption {
          type = types.singleLineStr;
        };
        unix-socket = mkOption {
          type = types.singleLineStr;
          default = "${cfg.container.shared-run-dir}/litellm.sock";
          readOnly = true;
        };
        host = mkOption {
          type = types.singleLineStr;
          default = "::1";
        };
        port = mkOption {
          type = types.port;
        };
        url = mkOption {
          type = types.singleLineStr;
          default = "http://${pkgs.myLib.bracketIpv6 "${cfg.host}:${toString cfg.port}"}";
          readOnly = true;
        };
        settings = mkOption {
          type = types.anything;
          default = {};
        };
        environment = mkOption {
          type = types.attrsOf types.str;
          default = {};
        };
        environmentFile = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    containers = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.container.name}.config = {config, ...}: let
          innerCfg = config;
        in {
          imports = [
            ./systemd-socket-proxyd.nix
          ];
          myOpt.systemd-socket-proxyd."${name}-litellm" = {
            origin = {
              inherit (innerCfg.services.litellm) host port;
              serviceName = "litellm";
            };
            proxy.ip-socket = cfg.unix-socket;
          };
          services.litellm = mkMerge [
            {
              inherit (cfg) stateDir host port settings environmentFile;
              enable = true;
              environment =
                mapAttrs (_: mkDefault) {}
                // cfg.environment;
            }
            cfg.modules.services.litellm
          ];
          systemd.services.litellm.serviceConfig = {
            NoNewPrivileges = true;
            PrivateIPC = true;
            ProtectSystem = "strict";
            ReadWritePaths = [cfg.stateDir];
            CapabilityBoundingSet = "";
            AmbientCapabilities = "";
            RestrictSUIDSGID = true;
            RemoveIPC = true;
            SystemCallFilter = [
              "@system-service"
              "~@privileged"
              "~@resources"
            ];
          };
        };
      })
      enabled);
  };
}
