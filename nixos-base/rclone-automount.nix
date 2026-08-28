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
          ...
        }: {
          options = {
            enable = mkOption {
              type = types.bool;
              default = false;
            };
            homeDirectory = mkOption {
              type = types.singleLineStr;
              default = outerCfg.myOpt.admin.homeDirectory;
            };
            remoteName = mkOption {
              type = types.singleLineStr;
              default = name;
            };
            mountPoint = mkOption {
              type = types.singleLineStr;
              default = "${config.homeDirectory}/${config.remoteName}";
            };
            remotePath = mkOption {
              type = types.singleLineStr;
              default = "";
            };
            options = mkOption {
              type = types.attrsOf types.singleLineStr;
              default = {};
              apply = mergeAttrs {
                vfs-cache-mode = "full";
                vfs-cache-max-age = "90d";
                vfs-cache-min-free-space = "20G";
                cache-dir = "${config.homeDirectory}/.cache/rclone/myOpt.rclone.automount";
                config = "${config.homeDirectory}/.config/rclone/rclone.conf";
                uid = toString outerCfg.myOpt.admin.uid;
                gid = toString outerCfg.myOpt.admin.gid;
              };
            };
          };
        }
      )
    );
  };

  config = mkIf (enabled-rclone-automount != {}) {
    environment.systemPackages = [pkgs.rclone];
    fileSystems =
      mapAttrs' (
        _: cfg:
          nameValuePair cfg.mountPoint {
            device = "${cfg.remoteName}:${cfg.remotePath}";
            fsType = "rclone";
            options =
              [
                "nofail"
                "x-systemd.automount"
                "_netdev"
                "args2env"
                "allow_other"
              ]
              ++ (mapAttrsToList (k: v: "${k}=${v}") cfg.options);
          }
      )
      enabled-rclone-automount;
  };
}
