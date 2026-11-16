{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
in {
  options.myPkgs = mkOption {
    type = types.attrsOf types.package;
    # type = types.submodule ({...}: {
    #   freeformType = types.anything;
    # });
  };
}
