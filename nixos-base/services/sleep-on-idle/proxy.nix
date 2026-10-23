{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  inherit (pkgs) writeShellScriptBin;
  systemd-socket-proxyd = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd";
  sleep = "${pkgs.coreutils}/bin/sleep";
  curl = getExe pkgs.curl;
  cgi-fcgi = getExe pkgs.fcgi;
in {
  systemd.services = concatMapAttrs (name1: cfg1: let
    inherit (cfg1) serviceName thawName freezeName health-check exit-idle-time TimeoutStartSec;
    SERVICE = "${serviceName}.service";
    THAW = "${thawName}.service";
    FREEZE = "${freezeName}.service";
    ExecStartPre = getExe (writeShellScriptBin "${serviceName}-health-check" ''
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
        SOCKET = "${proxy.name}.socket";
      in (nameValuePair proxy.name {
        requires = [SOCKET SERVICE THAW FREEZE];
        after = [SOCKET SERVICE THAW FREEZE];
        # requires = [SOCKET SERVICE FREEZE];
        # after = [SOCKET SERVICE FREEZE];

        serviceConfig = {
          inherit TimeoutStartSec ExecStartPre;
          ExecStart = "${systemd-socket-proxyd} --exit-idle-time=${toString exit-idle-time} ${origin.ip-socket}";
        };
      })))
      cfg1.endpoints)
  config.myOpt.sleep-on-idle;
}
