{
  config,
  lib,
  ...
}:
with lib; {
  options.myOpt.plasma6.enable = mkOption {
    type = types.bool;
    default = false;
  };
  config = mkIf config.myOpt.plasma6.enable {
    services.desktopManager.plasma6.enable = true;
    services.displayManager = {
      sddm.enable = true;
      sddm.wayland.enable = true;
    };
  };
}
