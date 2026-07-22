{
  config,
  lib,
  ...
}:
with lib; let
  PORT = config.myOpt.openssh.port;
in {
  options.myOpt.openssh.port = mkOption {
    type = types.nullOr types.port;
    default = null;
  };

  config = mkIf (PORT != null) {
    services.openssh = {
      enable = true;
      ports = [PORT];
      startWhenNeeded = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        AllowUsers = [config.myOpt.User];
      };
    };

    virtualisation.vmVariant = {
      networking.firewall.allowedTCPPorts = [PORT];
      virtualisation.forwardPorts = [
        {
          from = "host";
          host = {port = PORT;};
          guest = {port = PORT;};
        }
      ];
    };
  };
}
