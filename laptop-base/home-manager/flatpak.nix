{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  cfg = config.services.flatpak;
in {
  imports = [inputs.nix-flatpak.homeManagerModules.nix-flatpak];
  home.packages = optional cfg.enable pkgs.flatpak;
  services.flatpak.uninstallUnmanaged = mkDefault false;
}
