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
      inherit (cfg) thawName SLICE_or_SERVICE;
    in (nameValuePair thawName {
      unitConfig.StartLimitBurst = 0;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = getExe (writeShellScriptBin thawName ''
          ${systemctl} thaw ${SLICE_or_SERVICE} || true
        '');
      };
    }))
    config.myOpt.sleep-on-idle;
}
