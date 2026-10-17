{
  config,
  lib,
  utils,
  ...
}:
with lib; let
  enabled = filterAttrs (_: cfg: cfg.enable) config.myOpt.systemd-socket-proxyd;
  mkEndpointOpt = {
    self,
    serviceName,
  }: {
    serviceName = mkOption {
      type = types.nullOr types.singleLineStr;
      default = serviceName;
    };
    host = mkOption {
      type = types.nullOr types.singleLineStr;
      default = null;
    };
    port = mkOption {
      type = types.nullOr types.port;
      default = null;
    };
    ip-socket = mkOption {
      type = types.singleLineStr;
      default =
        if self.port != null && self.host != null
        then "${self.host}:${toString self.port}"
        else null;
    };
  };
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
        origin = mkEndpointOpt {
          self = cfg.origin;
          serviceName = name;
        };
        proxy = mkEndpointOpt {
          self = cfg.proxy;
          serviceName = "${cfg.origin.serviceName}-proxy";
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
