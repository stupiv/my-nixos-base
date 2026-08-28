{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.myOpt;
in {
  options.myOpt = {
    homeDir = mkOption {
      type = types.singleLineStr;
      default = "/home/${cfg.admin.username}";
    };
    downloadDir = mkOption {
      type = types.singleLineStr;
      default = "${cfg.homeDir}/Downloads";
    };
  };
}
