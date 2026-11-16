{
  imports = [
    ./common
    ./dnscrypt
    ./services
    ./terminal
    ./admin.nix
    ./bootloader.nix
    ./caddy.nix
    ./cloudlfared.nix
    # ./default.nix
    ./dirs.nix
    ./firmware.nix
    ./ipv6.nix
    ./networkmanager.nix
    ./nix.nix
    ./nix-ld.nix
    ./no-coredump.nix
    ./openssh.nix
    ./podman.nix
    ./shellcheck.nix
    ./sops.nix
    ./specialisation.nix
    ./time.nix
    ./vmVariant.nix
    ./zramSwap.nix
  ];
}
