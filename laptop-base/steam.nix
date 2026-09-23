{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.myOpt.steam;
in {
  options.myOpt.steam.enable = mkOption {
    type = types.bool;
    default = false;
  };

  config = mkIf cfg.enable {
    programs.steam.enable = true;
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (getName pkg) [
        "steam"
        "steam-unwrapped"
      ];
  };
}
