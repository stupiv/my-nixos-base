{
  config,
  lib,
  ...
}:
with lib; let
  enabled = filterAttrs (name: cfg: cfg.enable) config.myOpt.sleep-on-idle;
in {
  config = mkIf (enabled != {}) {
    systemd.sockets = mkMerge [
      {
        "sleep-on-idle-proxy@" = {
          socketConfig = {
            TriggerLimitBurst = 0;
            NoDelay = true;
          };
        };
      }
      (concatMapAttrs (name1: cfg1:
        mapAttrs' (name2: cfg2: let
          inherit (cfg2) proxy;
        in (nameValuePair proxy.name {
          overrideStrategy = "asDropin";
          wantedBy = ["sockets.target"];
          listenStreams = [proxy.ip-socket];
        }))
        cfg1.endpoints)
      enabled)
    ];
  };
}
