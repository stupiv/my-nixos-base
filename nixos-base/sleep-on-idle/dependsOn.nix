{
  config,
  lib,
  ...
}:
with lib; {
  systemd.services = mkMerge (
    mapAttrsToList (
      _: cfg: let
        common-config = {
          wantedBy = mkForce [];
          requires = ["${cfg.thawName}.service"];
          after = ["${cfg.thawName}.service"];
          unitConfig = {
            StopWhenUnneeded = false;
          };
          serviceConfig = {
            Slice = mkIf (cfg.sliceName != null) "${cfg.sliceName}.slice";
            RemainAfterExit = true;
          };
        };
      in (genAttrs (cfg.dependsOn ++ [cfg.serviceName]) (_: common-config))
    )
    config.myOpt.sleep-on-idle
  );
}
