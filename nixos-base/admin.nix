{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.myOpt.admin;
in {
  options.myOpt.admin = {
    username = mkOption {
      type = types.anything;
    };
    hashedPassword = mkOption {
      type = types.anything;
      description = "`mkpasswd 'your password'`";
    };
    homeDirectory = mkOption {
      type = types.singleLineStr;
      default = "/home/${cfg.username}";
      readOnly = true;
    };
    uid = mkOption {
      type = types.anything;
      default = 1000;
    };
    gid = mkOption {
      type = types.anything;
      default = cfg.uid;
    };
  };
  config = {
    users.users.${cfg.username} = {
      inherit (cfg) hashedPassword uid;
      home = cfg.homeDirectory;
      isNormalUser = true;
      extraGroups = ["wheel"];
    };
    users.groups.${cfg.username} = {
      inherit (cfg) gid;
    };
  };
}
