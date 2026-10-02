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
  services.flatpak = {
    enable = mkDefault true;
    update.auto = {
      enable = mkDefault true;
      onCalendar = mkDefault "*-05,11-*";
    };
  };
}
