{lib, ...}:
with lib; {
  services.caddy.openFirewall = mkDefault false;
}
