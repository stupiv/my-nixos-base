{
  config,
  lib,
  ...
}:
with lib; let
  inherit (config.myOpt) homeDir User;
in {
  options.myOpt = {
    homeDir = mkOption {
      type = types.singleLineStr;
      default = "/home/${User}";
    };
    downloadDir = mkOption {
      type = types.singleLineStr;
      default = "${homeDir}/Downloads";
    };
  };
}
