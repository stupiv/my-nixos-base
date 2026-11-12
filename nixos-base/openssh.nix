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
    port = mkOption {
      type = types.nullOr types.port;
      default = null;
    };
    cloudflared = {
      enable = mkOption {
        type = types.bool;
        default = cfg.cloudflared.tunnel-id != null;
        readOnly = true;
      };
      tunnel-id = mkOption {
        type = types.nullOr types.singleLineStr;
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
        ${cfg.cloudflared.tunnel-id} = {
          tunnelCfg.ingress = {
            ${cfg.cloudflared.hostname} = "ssh://localhost:${toString cfg.port}";
          };
        };
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
