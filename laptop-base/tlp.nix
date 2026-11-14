{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.services.tlp;
in {
  config = {
    assertions = [
      {
        assertion =
          !cfg.enable
          || (!config.services.power-profiles-daemon.enable && !config.services.thermald.enable && !config.powerManagement.powertop.enable && !config.services.auto-cpufreq.enable && !config.hardware.system76.power-daemon.enable && !config.services.throttled.enable);
        message = "See https://linrunner.de/tlp/faq/conflicts.html";
      }
    ];

    # See https://linrunner.de/tlp/faq/conflicts.html
    services.power-profiles-daemon.enable = mkIf (cfg.enable) false;
    services.thermald.enable = mkIf (cfg.enable) false;
    services.powerManagement.powertop.enable = mkIf (cfg.enable) false;
    services.auto-cpufreq.enable = mkIf (cfg.enable) false;
    hardware.system76.power-daemon.enable = mkIf (cfg.enable) false;
    services.throttled.enable = mkIf (cfg.enable) false;
    # See https://linrunner.de/tlp/faq/conflicts.html

    services.tlp = {
      enable = true;
      settings = {
        # See https://linrunner.de/tlp/settings/battery.html
        START_CHARGE_THRESH_BAT0 = 75;
        STOP_CHARGE_THRESH_BAT0 = 80;
        START_CHARGE_THRESH_BAT1 = 75;
        STOP_CHARGE_THRESH_BAT1 = 80;
        RESTORE_THRESHOLDS_ON_BAT = 1;
        # See https://linrunner.de/tlp/settings/battery.html

        # # See https://linrunner.de/tlp/faq/radio.html#slow-or-unstable-wi-fi-on-battery-power
        # WIFI_PWR_ON_BAL = "off";
        # WIFI_PWR_ON_SAV = "off";
        # WIFI_PWR_ON_BAT = "off";
        # # See https://linrunner.de/tlp/faq/radio.html#slow-or-unstable-wi-fi-on-battery-power

        # USB_EXCLUDE_PHONE = 1; # See https://linrunner.de/tlp/faq/usb.html#smartphone-does-not-charge-when-connected
        # USB_EXCLUDE_BTUSB = 1; # See https://linrunner.de/tlp/faq/radio.html#faq-bluetooth-unstable

        # # See https://linrunner.de/tlp/faq/audio.html
        # SOUND_POWER_SAVE_ON_PRF = 0;
        # SOUND_POWER_SAVE_ON_BAL = 0;
        # SOUND_POWER_SAVE_ON_SAV = 0;
        # SOUND_POWER_SAVE_ON_AC = 0;
        # SOUND_POWER_SAVE_ON_BAT = 0;
        # # See https://linrunner.de/tlp/faq/audio.html
      };
    };
  };
}
