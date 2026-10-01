{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
in {
  services.pipewire = {
    enable = mkDefault true;
    pulse.enable = mkDefault true;
  };
  programs.dconf.enable = mkDefault true; # for home-manager services.easyeffects.enable
}
