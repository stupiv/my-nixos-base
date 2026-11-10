{
  imports = [
    ./compose
    ./sleep-on-idle
    ./camofox.nix
    ./cloudflared.nix
    # ./default.nix
    ./fastcrw.nix
    ./hermes-agent.nix
    ./keycloak.nix
    ./litellm.nix
    ./mariadb.nix
    ./netns.nix
    ./postgresql.nix
    ./proxy-compose.nix
    ./rclone-automount.nix
    ./searxng.nix
    ./set-env-vars.nix
    ./squid.nix
    ./systemd-socket-proxyd.nix
    ./valkey.nix
  ];
}
