{
  config,
  lib,
  ...
}:
with lib; let
  enabled = filterAttrs (name: cfg: cfg.enable) config.myOpt.sleep-on-idle;
  systemctl = "${config.systemd.package}/bin/systemctl";
in {
  config = mkIf (enabled != {}) {
    systemd.services = mkMerge [
      {
        "sleep-on-idle-freeze@" = {
          unitConfig.StopWhenUnneeded = true;
          serviceConfig.RemainAfterExit = true;
        };
      }
      (mapAttrs' (_: cfg: (nameValuePair cfg.freezeName {
        overrideStrategy = "asDropin";
        serviceConfig = {
          ExecStart = "-${systemctl} thaw ${cfg.sliceUnit}";
          ExecStop = "-${systemctl} freeze ${cfg.sliceUnit}";
        };
      }))
      enabled)
    ];
  };
}
