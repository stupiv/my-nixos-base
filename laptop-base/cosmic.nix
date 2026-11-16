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
    services.desktopManager.cosmic.enable = true;

    services.displayManager.cosmic-greeter.enable = true;
    services.displayManager.defaultSession = "cosmic";
    # services.displayManager = {
    #   sddm.enable = true;
    #   sddm.wayland.enable = true;
    #   defaultSession = "cosmic";
    # };

    environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = 1;

    environment.cosmic.excludePackages = with pkgs; [
      cosmic-edit
      cosmic-player
      cosmic-screenshot
      cosmic-term
    ];
  };
}
