{
  imports = [
    ./compose
    ./sleep-on-idle
    ./WIP
    ./cloudflared.nix
    # ./default.nix
    ./keycloak.nix
    ./postgresql.nix
    ./proxy-compose.nix
    ./rclone-automount.nix
    ./systemd-socket-proxyd.nix
  ];
}
