{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.myOpt.ipv6;
in {
  options.myOpt.ipv6 = {
    dns.disable = mkOption {
      type = types.bool;
      default = false;
    };
    public-address = mkOption {
      type = types.nullOr types.str;
    };
    interface = mkOption {
      type = types.str;
    };
    gateway = mkOption {
      type = types.str;
    };
  };
  config = mkIf (cfg.public-address != null) {
    networking.interfaces = {
      ${cfg.interface}.ipv6.addresses = [
        {
          address = cfg.public-address;
          prefixLength = 64;
        }
      ];
    };
    networking.defaultGateway6 = {
      address = cfg.gateway;
      interface = cfg.interface;
    };
  };
}
