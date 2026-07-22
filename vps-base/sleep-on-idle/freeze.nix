{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  inherit (pkgs) writeShellScriptBin;
  systemctl = "${pkgs.systemd}/bin/systemctl";
in {
  systemd.services =
    mapAttrs' (_: cfg: let
      inherit (cfg) freezeName SLICE_or_SERVICE thawName;
    in (nameValuePair freezeName {
      unitConfig.StopWhenUnneeded = true;
      serviceConfig = {
        RemainAfterExit = true;
        ExecStart = getExe (writeShellScriptBin thawName ''
          ${systemctl} thaw ${SLICE_or_SERVICE} || true
        '');
        ExecStop = getExe (writeShellScriptBin freezeName ''
          ${systemctl} freeze ${SLICE_or_SERVICE} || true
        '');
      };
    }))
    config.myOpt.sleep-on-idle;
}
