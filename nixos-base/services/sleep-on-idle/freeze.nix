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
    systemd.services."sleep-on-idle-freeze@" = {
      unitConfig.StopWhenUnneeded = true;
      serviceConfig = {
        RemainAfterExit = true;
        ExecStart = "-${systemctl} thaw %i.slice";
        ExecStop = "-${systemctl} freeze %i.slice";
      };
    };
  };
}
