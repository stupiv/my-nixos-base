{
  config,
  lib,
  ...
}:
with lib; {
  systemd.slices =
    mapAttrs' (_: cfg: (nameValuePair cfg.sliceName {}))
    (filterAttrs (_: cfg: cfg.sliceName != null) config.myOpt.sleep-on-idle);
}
