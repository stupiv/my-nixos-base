{
  imports = [
    ./compose
    ./sleep-on-idle
    ./WIP
    ./cloudflared.nix
    # ./default.nix
    ./proxy-compose.nix
    ./rclone-automount.nix
    ./systemd-socket-proxyd.nix
  ];
}
