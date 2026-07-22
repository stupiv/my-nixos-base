{
  config,
  lib,
  ...
}:
with lib; {
  systemd.sockets = concatMapAttrs (name1: cfg1:
    mapAttrs' (name2: cfg2: let
      inherit (cfg2) proxy;
    in (nameValuePair proxy.name {
      wantedBy = ["sockets.target"];
      listenStreams = [proxy.socket-address];
      socketConfig = {
        TriggerLimitBurst = 0;
        NoDelay = true;
      };
    }))
    cfg1.endpoints)
  config.myOpt.sleep-on-idle;
}
