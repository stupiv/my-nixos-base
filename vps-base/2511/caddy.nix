{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.services.caddy;
in {
  options.services.caddy = {
    openFirewall = mkOption {
      type = types.bool;
      default = false;
    };
    httpPort = mkOption {
      default = 80;
      type = with types; nullOr port;
    };
    httpsPort = mkOption {
      default = 443;
      type = with types; nullOr port;
    };
  };

  config = {
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = filter (port: port != null) [
        cfg.httpPort
        cfg.httpsPort
      ];
      allowedUDPPorts = optional (cfg.httpsPort != null) cfg.httpsPort;
    };
  };
}
