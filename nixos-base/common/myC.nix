{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
in {
  options.myC = mkOption {
    type = types.anything;
  };
}
