{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  options.myOpt.cosmic.enable = mkOption {
    type = types.bool;
    default = false;
  };

  config = mkIf config.myOpt.cosmic.enable {
    services.displayManager.cosmic-greeter.enable = true;
    services.desktopManager.cosmic.enable = true;
    environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = 1;
  };
}
