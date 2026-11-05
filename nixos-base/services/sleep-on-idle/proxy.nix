{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  enabled = filterAttrs (name: cfg: cfg.enable) config.myOpt.sleep-on-idle;
  inherit (pkgs) writeShellScriptBin;
  systemd-socket-proxyd = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd";
  sleep = "${pkgs.coreutils}/bin/sleep";
  curl = getExe pkgs.curl;
  cgi-fcgi = getExe pkgs.fcgi;
in {
  config = mkIf (enabled != {}) {
    systemd.services = mkMerge [
      {
        # ExecStart is supplied by each instance drop-in.
        "sleep-on-idle-proxy@" = {};
      }
      (concatMapAttrs (name1: cfg1: let
        inherit (cfg1) sliceName freezeUnit health-check exit-idle-time TimeoutStartSec;
        ExecStartPre = getExe (writeShellScriptBin "${sliceName}-health-check" ''
          until ${
            if (hasPrefix "/" health-check.ip-socket)
            then
              (
                if (hasInfix "phpfpm" health-check.ip-socket)
                then "${cgi-fcgi} -bind -connect ${health-check.ip-socket}"
                else "${curl} -sf --unix-socket ${health-check.ip-socket} http://localhost${health-check.path}"
              )
            else "${curl} -sf ${health-check.ip-socket}${health-check.path}"
          }; do ${sleep} ${health-check.sleep}; done
        '');
      in
        assert (health-check.ip-socket != null);
          (mapAttrs' (name2: cfg2: let
            inherit (cfg2) proxy origin;
            socketUnit = "${proxy.name}.socket";
          in (nameValuePair proxy.name {
            overrideStrategy = "asDropin";
            requires = [socketUnit freezeUnit];
            after = [socketUnit freezeUnit];
            serviceConfig = {
              inherit TimeoutStartSec ExecStartPre;
              ExecStart = "${systemd-socket-proxyd} --exit-idle-time=${toString exit-idle-time} ${origin.ip-socket}";
            };
          })))
          cfg1.endpoints)
      enabled)
    ];
  };
}
