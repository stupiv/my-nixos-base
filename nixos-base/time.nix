{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.myOpt;
in {
  i18n.extraLocaleSettings.LC_TIME = "en_DK.UTF-8";
  time.timeZone = "Asia/Ho_Chi_Minh";
}
