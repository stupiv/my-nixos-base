{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  cfg = config.programs.zen-browser;
  mkPath = pkg: desktop: "${pkg}/share/applications/${desktop}";
in {
  imports = [inputs.zen-browser-flake.homeModules.default];
  programs.zen-browser = {
    nixGL.enable = mkDefault true;
    setAsDefaultBrowser = mkDefault true;
  };
  xdg.autostart.entries = optional cfg.enable (mkPath cfg.package "zen-beta.desktop");
}
