{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; {
  imports = [inputs.nix-flatpak.nixosModules.nix-flatpak];
  services.flatpak.uninstallUnmanaged = mkDefault true;
}
