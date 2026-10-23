{
  imports = [
    ./compose
    ./sleep-on-idle
    ./camofox.nix
    ./cloudflared.nix
    # ./default.nix
    ./fastcrw.nix
    ./litellm.nix
    ./netns.nix
    ./proxy-compose.nix
    ./qdrant.nix
    ./rclone-automount.nix
    ./searxng.nix
    ./systemd-socket-proxyd.nix
  ];
}
