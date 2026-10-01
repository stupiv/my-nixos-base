{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
in {
  imports = [inputs.nix-flatpak.nixosModules.nix-flatpak];
  services.flatpak.uninstallUnmanaged = mkDefault true;
}
