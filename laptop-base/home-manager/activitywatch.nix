{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  inherit (pkgs) pkgs-2611;
  cfg = config.services.activitywatch;

  awVersion = "0.14.0b8";
  awAppImage = pkgs.fetchurl {
    url = "https://github.com/ActivityWatch/activitywatch/releases/download/v${awVersion}/activitywatch-linux-x86_64.AppImage";
    hash = "sha256-k9I2PSwQ0nmNUB10TlzVuWyPFGj9fVbQ7JXSxMYDmDE=";
  };
  awContents = pkgs.appimageTools.extract {
    pname = "activitywatch";
    version = awVersion;
    src = awAppImage;
    postExtract = ''
      find $out -mindepth 1 -maxdepth 1 -not -name aw-server-rust -exec rm -rf {} +
    '';
  };
  awServer =
    pkgs.runCommandLocal "aw-server-${awVersion}" {
      nativeBuildInputs = [pkgs.autoPatchelfHook];
      buildInputs = [
        pkgs.glibc
        pkgs.stdenv.cc.cc.lib
      ];
      meta.mainProgram = "aw-server";
    } ''
      install -Dm755 ${awContents}/aw-server-rust/aw-server-rust $out/bin/aw-server
    '';
in {
  services.activitywatch = {
    enable = true;
    package = awServer;
    watchers.awatcher = {
      package = pkgs-2611.awatcher;
      executable = "awatcher";
    };
  };
  systemd.user.targets.activitywatch = mkIf (cfg.enable) {
    Unit.After = mkForce ["graphical-session.target"];
    Install.WantedBy = mkForce ["graphical-session.target"];
  };
}
