{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.myOpt.openssh;
in {
  options.myOpt.openssh = {
    enable = mkOption {
      type = types.bool;
    };
    modules = {
      cloudflared = mkOption {
        type = types.anything;
      };
    };
    port = mkOption {
      type = types.nullOr types.port;
      default = null;
    };
    cloudflared = {
      enable = mkOption {
        type = types.bool;
      };
      hostname = mkOption {
        type = types.singleLineStr;
      };
    };
  };

  config = mkMerge [
    (mkIf (cfg.enable) {
      services.openssh = {
        enable = true;
        ports = [cfg.port];
      };
      myOpt.cloudflared = (mkIf cfg.cloudflared.enable) {
        ${cfg.modules.cloudflared.tunnel-id} = mkMerge [
          cfg.modules.cloudflared
          {
            tunnelCfg.ingress = {
              ${cfg.cloudflared.hostname} = "ssh://localhost:${toString cfg.port}";
            };
          }
        ];
      };
    })
    {
      services.openssh = {
        startWhenNeeded = true;
        settings = {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
        };
      };
    }
  ];
}
