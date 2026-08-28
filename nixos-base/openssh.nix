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
      default = cfg.cloudflared.enable;
      readOnly = true;
    };
    port = mkOption {
      type = types.nullOr types.port;
      default = null;
    };
    cloudflared = {
      enable = mkOption {
        type = types.bool;
        default = cfg.cloudflared.tunnel_id != null;
        readOnly = true;
      };
      tunnel_id = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      hostname = mkOption {
        type = types.str;
      };
    };
    authorizedKeys = mkOption {
      type = types.anything;
    };
  };

  config = mkIf (cfg.enable) {
    users.users.${config.myOpt.admin.username}.openssh.authorizedKeys.keys = cfg.authorizedKeys;
    myOpt.cloudflared.${cfg.cloudflared.tunnel_id}.ingress = mkIf cfg.cloudflared.enable {
      ${cfg.cloudflared.hostname} = "ssh://localhost:${toString cfg.port}";
    };
    services.openssh = {
      enable = true;
      ports = [cfg.port];
      startWhenNeeded = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        AllowUsers = [config.myOpt.admin.username];
      };
    };
    virtualisation.vmVariant = {
      services.openssh.openFirewall = true;
      virtualisation.forwardPorts = [
        {
          from = "host";
          host = {port = cfg.port;};
          guest = {port = cfg.port;};
        }
      ];
    };
  };
}
