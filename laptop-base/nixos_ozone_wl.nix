{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
in {
  environment.sessionVariables.NIXOS_OZONE_WL = mkDefault "1";
}
