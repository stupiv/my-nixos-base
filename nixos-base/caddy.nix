{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  config = mkIf (config.services.caddy.enable) {
    services.caddy.package = config.myPkgs.caddy;
    systemd.services.caddy.path =  (with pkgs; [
      nss
      nss.tools
    ]);
  };
}
