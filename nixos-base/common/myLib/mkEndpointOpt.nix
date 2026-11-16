{
  nixpkgs.overlays = [
    (final: prev: {
      myLib = prev.myLib.overrideScope (ml-final: ml-prev: {
        mkEndpointOpt = {
          cfg,
          ipv6-brackets,
          default-ip-socket ? null,
          ...
        }:
          with prev.lib;
          assert (ipv6-brackets == true) || (ipv6-brackets == false); {
            port = mkOption {
              type = types.nullOr types.port;
              default = null;
            };
            host = mkOption {
              type = types.singleLineStr;
              default = "::1";
            };
            ip-socket = mkOption {
              type = types.singleLineStr;
              default =
                if cfg.port != null
                then "${cfg.host}:${toString cfg.port}"
                else default-ip-socket;
              apply =
                if ipv6-brackets
                then ml-final.bracketIpv6
                else ml-final.unbracketIpv6;
            };
          };
      });
    })
  ];
}
