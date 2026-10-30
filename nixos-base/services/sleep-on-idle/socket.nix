{
  config,
  lib,
  ...
}:
with lib; let
  enabled = filterAttrs (name: cfg: cfg.enable) config.myOpt.sleep-on-idle;
in {
  systemd.sockets = concatMapAttrs (name1: cfg1:
    mapAttrs' (name2: cfg2: let
      inherit (cfg2) proxy;
    in (nameValuePair proxy.name {
      wantedBy = ["sockets.target"];
      listenStreams = [proxy.ip-socket];
      socketConfig = {
        TriggerLimitBurst = 0;
        NoDelay = true;
      };
    }))
    cfg1.endpoints)
  enabled;
}
