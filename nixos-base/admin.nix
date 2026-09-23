{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.myOpt.admin;
  openssh.enable = cfg.authorizedKeys != null;
in {
  options.myOpt.admin = {
    username = mkOption {
      type = types.anything;
    };
    hashedPassword = mkOption {
      type = types.anything;
      description = "`mkpasswd 'your password'`";
    };
    authorizedKeys = mkOption {
      type = types.anything;
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
    myOpt.openssh.enable = mkDefault openssh.enable;
    services.openssh.settings.AllowUsers = (mkIf openssh.enable) [cfg.username];

    users.users.${cfg.username} = {
      inherit (cfg) hashedPassword uid;
      home = cfg.homeDirectory;
      isNormalUser = true;
      extraGroups = ["wheel"];
      openssh.authorizedKeys.keys = (mkIf openssh.enable) cfg.authorizedKeys;
    };
    users.groups.${cfg.username} = {
      inherit (cfg) gid;
    };
  };
}
