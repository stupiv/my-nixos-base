{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
in {
  options.myC = mkOption {
    type = types.anything;
  };
  config.myC = {
    my-nixos-base-root = inputs.out;
  };
}
