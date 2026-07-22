{
  config,
  lib,
  ...
}:
with lib; let
  inherit (config.myOpt) User;
in {
  options.myOpt.User = mkOption {
    type = types.singleLineStr;
  };
  config.users.users.${User} = {
    isNormalUser = true;
    extraGroups = ["wheel"];
  };
}
