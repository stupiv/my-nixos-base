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
  services.flatpak = {
    enable = mkDefault true;
    update.auto = {
      enable = mkDefault true;
      onCalendar = mkDefault "*-05,11-*";
    };
  };
}
