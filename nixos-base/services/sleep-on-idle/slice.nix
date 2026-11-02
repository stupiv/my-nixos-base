{
  config,
  lib,
  ...
}:
with lib; let
  enabled = filterAttrs (name: cfg: cfg.enable) config.myOpt.sleep-on-idle;
in {
  config = mkIf (enabled != {}) {
    systemd.slices =
      mapAttrs' (_: cfg: (nameValuePair cfg.sliceName {}))
      enabled;
  };
}
