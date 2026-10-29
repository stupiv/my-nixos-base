{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  cfg = config.myOpt.zen-browser;
  mkPath = pkg: desktop: "${pkg}/share/applications/${desktop}";
in {
  imports = [inputs.zen-browser-flake.homeModules.default];

  options.myOpt.zen-browser = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    autoStart = mkOption {
      type = types.bool;
      default = true;
    };
    setAsDefaultBrowser = mkOption {
      type = types.bool;
      default = true;
    };
  };

  config = mkIf (cfg.enable) {
    programs.zen-browser = {
      enable = true;
      nixGL.enable = mkDefault true;
      setAsDefaultBrowser = cfg.setAsDefaultBrowser;
    };
    xdg.autostart.entries = optional cfg.autoStart (mkPath cfg.package "zen-beta.desktop");
  };
}
