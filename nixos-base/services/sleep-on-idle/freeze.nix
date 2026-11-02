{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  enabled = filterAttrs (name: cfg: cfg.enable) config.myOpt.sleep-on-idle;
  systemctl = "${config.systemd.package}/bin/systemctl";
in {
  config = mkIf (enabled != {}) {
    systemd.services =
      mapAttrs' (_: cfg: (nameValuePair cfg.freezeName {
        unitConfig.StopWhenUnneeded = true;
        serviceConfig = {
          RemainAfterExit = true;
          ExecStart = "-${systemctl} thaw ${cfg.sliceUnit}";
          ExecStop = "-${systemctl} freeze ${cfg.sliceUnit}";
        };
      }))
      enabled;
  };
}
