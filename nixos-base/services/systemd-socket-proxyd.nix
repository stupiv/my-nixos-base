{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.systemd-socket-proxyd;
  inherit (pkgs.myLib) mkEndpointOpt;
in {
  imports = [
    ../common/myLib/mkEndpointOpt.nix
  ];
  options.myOpt.systemd-socket-proxyd = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        origin =
          mkEndpointOpt {
            cfg = cfg.origin;
            ipv6-brackets = false; # proxyd dial target: no brackets
          }
          // {
            serviceName = mkOption {
              type = types.singleLineStr;
            };
          };
        proxy =
          mkEndpointOpt {
            cfg = cfg.proxy;
            ipv6-brackets = true; # ListenStream=: brackets required
          }
          // {
            serviceName = mkOption {
              type = types.singleLineStr;
              default = name;
            };
          };
      };
    }));
  };
  config = mkIf (enabled != {}) {
    systemd.sockets = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.proxy.serviceName} = {
          wantedBy = ["sockets.target"];
          listenStreams = [cfg.proxy.ip-socket];
        };
      })
      enabled);
    systemd.services = mkMerge (mapAttrsToList (_: cfg: let
        originUnit = "${cfg.origin.serviceName}.service";
        socketUnit = "${cfg.proxy.serviceName}.socket";
        systemd-socket-proxyd = "${outerCfg.systemd.package}/lib/systemd/systemd-socket-proxyd";
      in {
        ${cfg.proxy.serviceName} = {
          requires = [socketUnit originUnit];
          after = [socketUnit originUnit];
          serviceConfig.ExecStart = utils.escapeSystemdExecArgs [
            systemd-socket-proxyd
            cfg.origin.ip-socket
          ];
        };
      })
      enabled);
  };
}
