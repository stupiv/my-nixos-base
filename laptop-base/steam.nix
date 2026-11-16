{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  cfg = config.myOpt.steam;
in {
  options.myOpt.steam.enable = mkOption {
    type = types.bool;
    default = false;
  };
  config = mkIf (cfg.enable) {
    programs.gamescope = {
      enable = true;
    };
    programs.steam = {
      enable = true;
      gamescopeSession = {
        enable = true;
        args = ["-W" "1920" "-H" "1080" "-r" "24"];
      };
    };
  };
}
