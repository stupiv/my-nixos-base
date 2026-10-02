{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  cfg = config.myOpt.cosmic;
in {
  options.myOpt.cosmic.enable = mkOption {
    type = types.bool;
    default = false;
  };

  config = mkIf cfg.enable {
    environment.cosmic.excludePackages = with pkgs; [
      cosmic-edit
      cosmic-player
      cosmic-screenshot
      cosmic-term
    ];
    services.desktopManager = {
      cosmic.enable = mkDefault true;
      cosmic-greeter.enable = mkDefault true;
    };
    environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = mkDefault 1;
  };
}
