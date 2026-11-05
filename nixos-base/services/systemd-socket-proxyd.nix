{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
with lib; let
  inherit (pkgs.myLib) mkEndpointOpt;
  enabled = filterAttrs (_: cfg: cfg.enable) config.myOpt.systemd-socket-proxyd;
in {
  imports = [
    ../../myLib
  ];
  options.myOpt.systemd-socket-proxyd = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({
      name,
      config,
      ...
    }: let
      cfg = config;
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
              default = "systemd-socket-proxyd@${name}";
              readOnly = true;
            };
          };
      };
    }));
  };
  config = mkIf (enabled != {}) {
    systemd.sockets = mkMerge [
      {
        "systemd-socket-proxyd@" = {};
      }
      (mapAttrsToList (_: cfg: {
          ${cfg.proxy.serviceName} = {
            overrideStrategy = "asDropin";
            wantedBy = ["sockets.target"];
            listenStreams = [cfg.proxy.ip-socket];
          };
        })
        enabled)
    ];
    systemd.services = mkMerge [
      {
        "systemd-socket-proxyd@" = {
          requires = ["systemd-socket-proxyd@%i.socket"];
          after = ["systemd-socket-proxyd@%i.socket"];
        };
      }
      (mapAttrsToList (_: cfg: let
          originUnit = "${cfg.origin.serviceName}.service";
          systemd-socket-proxyd = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd";
        in {
          ${cfg.proxy.serviceName} = {
            overrideStrategy = "asDropin";
            requires = [originUnit];
            after = [originUnit];
            serviceConfig.ExecStart = utils.escapeSystemdExecArgs [
              systemd-socket-proxyd
              cfg.origin.ip-socket
            ];
          };
        })
        enabled)
    ];
  };
}
