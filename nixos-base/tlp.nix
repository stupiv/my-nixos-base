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
      settings = {
        # See https://linrunner.de/tlp/settings/battery.html
        START_CHARGE_THRESH_BAT0 = 75;
        STOP_CHARGE_THRESH_BAT0 = 80;
        START_CHARGE_THRESH_BAT1 = 75;
        STOP_CHARGE_THRESH_BAT1 = 80;
        RESTORE_THRESHOLDS_ON_BAT = 1;
        #
        TLP_AUTO_SWITCH = 0;
        TLP_PROFILE_DEFAULT = "SAV";
        #
        USB_EXLUDE_PHONE = 1; # See https://linrunner.de/tlp/faq/usb.html#smartphone-does-not-charge-when-connected
        WIFI_PWR_ON_BAT = "off"; # See https://linrunner.de/tlp/faq/radio.html#slow-or-unstable-wi-fi-on-battery-power
        USB_EXCLUDE_BTUSB = 1; # See https://linrunner.de/tlp/faq/radio.html#faq-bluetooth-unstable
        # SOUND_POWER_SAVE_ON_AC = 0; # See https://linrunner.de/tlp/faq/audio.html
        # SOUND_POWER_SAVE_ON_BAT = 0; # See https://linrunner.de/tlp/faq/audio.html
      };
    };
  };
}
