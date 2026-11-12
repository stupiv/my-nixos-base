{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.myOpt.ipv6;
in {
  options.myOpt.ipv6 = {
    public-address = mkOption {
      type = types.nullOr types.singleLineStr;
    };
    interface = mkOption {
      type = types.singleLineStr;
    };
    gateway = mkOption {
      type = types.singleLineStr;
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
