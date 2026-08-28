{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  systemd.services.caddy.path = mkIf config.services.caddy.enable (with pkgs; [
    nss
    nss.tools
  ]);
}
