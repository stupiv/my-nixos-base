{lib, ...}:
with lib; {
  services.caddy.openFirewall = false;
}
