{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.myOpt.ipv6;
in {
  options.myOpt.ipv6 = {
    enable = mkOption {
      type = types.bool;
    };
    public = {
      enable = mkOption {
        type = types.bool;
      };
      address = mkOption {
        type = types.str;
      };
    };
    interface = mkOption {
      type = types.str;
    };
    gateway = mkOption {
      type = types.str;
    };
  };

  config = {
    services.dnscrypt-proxy.settings.ipv6_servers = cfg.enable; # Use servers reachable over IPv6 -- Do not enable if you don't have IPv6 connectivity
    networking.enableIPv6 = cfg.enable;

    networking.interfaces = mkIf (cfg.enable && cfg.public.enable) {
      ${cfg.interface}.ipv6.addresses = [
        {
          address = cfg.public.address;
          prefixLength = 64;
        }
      ];
    };
    networking.defaultGateway6 = mkIf (cfg.enable && cfg.public.enable) {
      address = cfg.gateway;
      interface = cfg.interface;
    };
  };
}
