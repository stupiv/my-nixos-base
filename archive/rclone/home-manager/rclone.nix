{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.myOpt.rclone;
in {
  options.myOpt.rclone = mkOption {
    type = types.anything;
    default = {};
  };

  config = mkIf (cfg != {}) {
    programs.rclone = mkMerge [
      cfg
      {
        enable = mkDefault true;
        remotes =
          mapAttrs' (remoteName: remote: (nameValuePair remoteName {
            mounts."/".options = {
              mountPoint = mkDefault "${config.home.homeDirectory}/${remoteName}";
              cache-dir = mkDefault "${config.home.homeDirectory}/cache/rclone_${remoteName}/";
              vfs-cache-mode = mkDefault "full";
              vfs-cache-max-age = mkDefault "90d";
              vfs-cache-min-free-space = mkDefault "20G";
            };
          }))
          cfg.remotes;
      }
    ];
  };
}
