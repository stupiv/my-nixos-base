{
  imports = [
    ../nixos-base
    ./2511
    ./pkgs
    ./services
    ./sleep-on-idle
    ./caddy.nix
    ./cloudflared.nix
    # ./default.nix
    ./openssh.nix
    ./podman.nix
    ./proxy-compose.nix
    # ./restart.nix
    ./sops.nix
  ];
}
