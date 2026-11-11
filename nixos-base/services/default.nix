{
  imports = [
    ./compose
    ./sleep-on-idle
    ./cloudflared.nix
    # ./default.nix
    ./hermes-agent.nix
    ./keycloak.nix
    ./mariadb.nix
    ./netns.nix
    ./postgresql.nix
    ./proxy-compose.nix
    ./rclone-automount.nix
    ./set-env-vars.nix
    ./squid.nix
    ./systemd-socket-proxyd.nix
    ./valkey.nix
  ];
}
