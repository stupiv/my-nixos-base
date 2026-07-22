{
  config,
  lib,
  ...
}:
with lib; {
  config = {
    assertions = [
      {
        assertion =
          !config.services.tlp.enable
          || (!config.services.power-profiles-daemon.enable && !config.services.thermald.enable && !config.powerManagement.powertop.enable);
      }
    ];
    services.power-profiles-daemon.enable = mkIf (config.services.tlp.enable) false; # See https://linrunner.de/tlp/faq/ppd.html#does-power-profiles-daemon-conflict-with-tlp
    services.thermald.enable = mkIf (config.services.tlp.enable) false; # See https://linrunner.de/tlp/faq/powercon.html#high-fan-speed
    powerManagement.powertop.enable = mkIf (config.services.tlp.enable) false;

    services.tlp = {
      enable = true;
      settings = {
        # See https://linrunner.de/tlp/settings/battery.html
        START_CHARGE_THRESH_BAT0 = 75;
        STOP_CHARGE_THRESH_BAT0 = 80;
        START_CHARGE_THRESH_BAT1 = 75;
        STOP_CHARGE_THRESH_BAT1 = 80;
        RESTORE_THRESHOLDS_ON_BAT = 1;
        #
        TLP_DEFAULT_MODE = "BAT";
        TLP_PERSISTENT_DEFAULT = 1;
        #
        USB_EXLUDE_PHONE = 1; # Charge smartphone
        WIFI_PWR_ON_BAT = "off"; # Power saving mode can cause an unstable Wi-Fi link.
        USB_EXCLUDE_BTUSB = 1; # solve stability issues with bluetooth connections
      };
    };
  };
}
