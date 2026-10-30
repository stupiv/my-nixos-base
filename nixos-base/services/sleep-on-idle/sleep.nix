{
  config,
  lib,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.sleep-on-idle;
in {
  systemd.services = mkMerge (
    mapAttrsToList (
      _: cfg: (genAttrs (
          cfg.sleep.systemd-services
          ++ (map (containerName: outerCfg.virtualisation.oci-containers.${containerName}.serviceName) cfg.sleep.oci-containers)
        ) (_: {
          wantedBy = mkForce ["${cfg.freezeUnit}"];
          after = ["${cfg.freezeUnit}"];
          unitConfig = {
            StopWhenUnneeded = false;
          };
          serviceConfig = {
            Slice = mkForce "${cfg.sliceUnit}";
            RemainAfterExit = true;
          };
        }))
    )
    enabled
  );
  virtualisation.oci-containers = mkMerge (
    mapAttrsToList (
      _: cfg: (genAttrs cfg.sleep.oci-containers (_: {
        extraOptions = ["--cgroup-parent=${cfg.sliceUnit}"];
      }))
    )
    enabled
  );
}
