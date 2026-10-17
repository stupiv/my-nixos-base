{
  config,
  lib,
  utils,
  ...
}:
with lib; let
  inherit (pkgs.myLib) mkEndpointOpt;
  enabled = filterAttrs (_: cfg: cfg.enable) config.myOpt.systemd-socket-proxyd;
  custom-mkEndpointOpt = args: ((mkEndpointOpt args)
    // {
      serviceName = mkOption {
        type = types.nullOr types.singleLineStr;
        default = args.serviceName;
      };
    });
in {
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
        origin = custom-mkEndpointOpt {
          cfg = cfg.origin;
          serviceName = name;
          ipv6-brackes = false; # proxyd dial target: no brackets
        };
        proxy = custom-mkEndpointOpt {
          cfg = cfg.proxy;
          serviceName = "${cfg.origin.serviceName}-proxy";
          ipv6-brackes = true; # ListenStream=: brackets required
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    systemd.sockets =
      mapAttrs' (_: cfg: (nameValuePair (cfg.proxy.serviceName) {
        wantedBy = ["sockets.target"];
        listenStreams = [cfg.proxy.ip-socket];
      }))
      enabled;
    systemd.services =
      mapAttrs' (_: cfg: let
        socketUnit = "${cfg.proxy.serviceName}.socket";
        originUnit = "${cfg.origin.serviceName}.service";
        systemd-socket-proxyd = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd";
      in (
        nameValuePair (cfg.proxy.serviceName) {
          requires = [socketUnit originUnit];
          after = [socketUnit originUnit];
          serviceConfig = {
            ExecStart = utils.escapeSystemdExecArgs [
              systemd-socket-proxyd
              cfg.origin.ip-socket
            ];
          };
        }
      ))
      enabled;
  };
}
