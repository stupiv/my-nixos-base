{
  config,
  lib,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.sleep-on-idle;
in {
  config = mkIf (enabled != {}) {
    systemd.services = mkMerge (mapAttrsToList (_: cfg: (genAttrs (
        (cfg.set-cgroup-parent.systemd-services)
        ++ (map (oci-con: outerCfg.virtualisation.oci-containers.containers.${oci-con}.serviceName) cfg.set-cgroup-parent.oci-containers)
        ++ (map (nixos-con: "container@${nixos-con}") cfg.set-cgroup-parent.nixos-containers)
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
      })))
    enabled);
    virtualisation.oci-containers.containers = mkMerge (mapAttrsToList (_: cfg: (genAttrs cfg.set-cgroup-parent.oci-containers (_: {
        extraOptions = ["--cgroup-parent=${cfg.sliceUnit}"];
      })))
      enabled);
  };
}
