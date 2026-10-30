{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  enabled = filterAttrs (name: cfg: cfg.enable) config.myOpt.sleep-on-idle;
  inherit (pkgs) writeShellScriptBin;
  systemctl = "${config.systemd.package}/bin/systemctl";
in {
  systemd.services =
    mapAttrs' (_: cfg: let
      inherit (cfg) freezeName sliceUnit thawName;
    in (nameValuePair freezeName {
      unitConfig.StopWhenUnneeded = true;
      serviceConfig = {
        RemainAfterExit = true;
        ExecStart = getExe (writeShellScriptBin thawName ''
          ${systemctl} thaw ${sliceUnit} || true
        '');
        ExecStop = getExe (writeShellScriptBin freezeName ''
          ${systemctl} freeze ${sliceUnit} || true
        '');
      };
    }))
    enabled;
}
