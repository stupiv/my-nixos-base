{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  config = mkIf (config.services.cloudflared.enable) {
    services.cloudflared.package = config.myPkgs.cloudflared;
  };
}
