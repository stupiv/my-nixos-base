{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  inherit (config.xdg.userDirs) download;
in {
  xdg = {
    enable = mkDefault true;
    autostart.enable = mkDefault true;
    mimeApps.enable = mkDefault true;
    userDirs = {
      enable = mkDefault true;
      documents = mkDefault download;
      music = mkDefault download;
      pictures = mkDefault download;
      videos = mkDefault download;
    };
  };
}
