{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.myOpt.openssh;
  cloudflared.enable = cfg.cloudflared.tunnel-id != null;
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
      tunnel-id = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      hostname = mkOption {
        type = types.str;
      };
    };
  };

  config = mkMerge [
    (mkIf (cfg.enable) {
      services.openssh = {
        enable = true;
        ports = [cfg.port];
      };
      myOpt.cloudflared = (mkIf cloudflared.enable) {
        ${cfg.cloudflared.tunnel-id}.ingress = {
          ${cfg.cloudflared.hostname} = "ssh://localhost:${toString cfg.port}";
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
