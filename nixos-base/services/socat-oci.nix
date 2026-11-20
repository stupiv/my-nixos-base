{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.socat-oci;
in {
  options.myOpt.socat-oci = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        origin = {
          oci-container.name = mkOption {
            type = types.singleLineStr;
          };
          host = mkOption {
            type = types.singleLineStr;
          };
          port = mkOption {
            type = types.port;
          };
        };
        proxy.unix-socket = mkOption {
          type = types.strMatching "^/run/[^/]+/.*[^/]$";
        };
        uid = mkOption {
          type = types.int;
        };
        gid = mkOption {
          type = types.int;
        };
        mode= mkOption {
          type = types.strMatcing "^0[0-7]{3}$";
        };
      };
    }));
  };
  config = mkIf (enabled != {}) {
    systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: [
        "d ${builtins.dirOf cfg.proxy.unix.socket} ${cfg.mode} ${toString cfg.uid} ${toString cfg.gid} - -"
      ])
      enabled);

    virtualisation.oci-containers = {
      containers = mkMerge (mapAttrsToList (_: cfg: {
          ${cfg.serviceName} = {
            imageStream = pkgs.dockerTools.streamLayeredImage {
              contents = [pkgs.socat];
              config.Cmd = [(getExe pkgs.socat)];
            };
            dependsOn = [
              cfg.origin.oci-container.name
            ];
            extraOptions = [
              "--network=container:${cfg.origin.oci-container.name}"
            ];
            volumes = [
              "${builtins.dirOf cfg.proxy.unix.socket}:${builtins.dirOf cfg.proxy.unix.socket}"
            ];
            cmd = [
              "TCP-LISTEN:${toString cfg.origin.port},bind=${cfg.origin.host}"
              "UNIX-CONNECT:${cfg.proxy.unix-socket},mode=${cfg.mode},user=${toString cfg.uid},group=${toString cfg.gid}"
            ];
          };
        })
        enabled);
    };
  };
}
