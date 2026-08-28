{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  enabled-rclone-automount = filterAttrs (_: cfg: cfg.enable) config.myOpt.rclone.automount;
  outerCfg = config;
in {
  options.myOpt.rclone.automount = mkOption {
    default = {};
    type = types.attrsOf (
      types.submodule (
        {
          name,
          config,
        }: {
          options = {
            enable = mkOption {
              type = types.bool;
              default = true;
            };
            remoteName = mkOption {
              type = types.singleLineStr;
              default = name;
            };
            User = mkOption {
              type = types.singleLineStr;
              default = outerCfg.myOpt.admin.username;
            };
            mountPoint = mkOption {
              type = types.singleLineStr;
              default = "/home/${config.User}/${config.remoteName}";
            };
            remotePath = mkOption {
              type = types.singleLineStr;
              default = "";
            };
            options = mkOption {
              type = types.attrsOf (
                types.nullOr (types.oneOf [
                  types.bool
                  types.int
                  types.float
                  types.singleLineStr
                ])
              );
              default = {};
              apply = mergeAttrs {
                vfs-cache-mode = "full";
                vfs-cache-max-age = "90d";
                vfs-cache-min-free-space = "20G";
                cache-dir = "/home/${config.User}/cache/rclone_${config.remoteName}";
              };
            };
          };
        }
      )
    );
  };

  config = mkIf (enabled-rclone-automount != {}) {
    environment.systemPackages = with pkgs; [
      rclone
    ];
    systemd.services =
      mapAttrs' (
        name: cfg:
          nameValuePair "rclone-automount-${name}" {
            wantedBy = ["multi-user.target"];
            after = ["network-online.target"];
            requires = ["network-online.target"];

            path = with pkgs; [rclone fuse3];
            serviceConfig = {
              Type = "notify";
              User = cfg.User;
              ExecStartPre = escapeShellArgs [
                "mkdir"
                "-p"
                cfg.mountPoint
                cfg.cacheDir
              ];
              ExecStart = escapeShellArgs ([
                  "rclone"
                  "mount"
                ]
                ++ (cli.toGNUCommandLine {} cfg.options)
                ++ [
                  "${cfg.remoteName}:${cfg.remotePath}"
                  cfg.mountPoint
                ]);

              ExecStop = escapeShellArgs [
                "fusermount3"
                "-u"
                cfg.mountPoint
              ];

              Restart = mkDefault "on-failure";
              RestartMaxDelaySec = mkDefault "5min";
              RestartSteps = mkDefault "10";
              RestartSec = mkDefault "1";
            };
          }
      )
      enabled-rclone-automount;
  };
}
