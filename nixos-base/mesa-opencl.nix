{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.myOpt.mesa-opencl;
in {
  options.myOpt.mesa-opencl = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    RUSTICL_ENABLE = mkOption {
      type = types.singleLineStr;
    };
  };
  config = mkIf (cfg.enable) {
    hardware.graphics.extraPackages = with pkgs; [
      mesa.opencl
    ];
    environment.variables = {inherit (cfg) RUSTICL_ENABLE;};
  };
}
