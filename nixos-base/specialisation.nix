{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
in {
  options.myOpt.specialisation = mkOption {
    default = {};
    type = types.attrsOf (types.submodule {
      options = {
        inside = mkOption {
          type = types.bool;
          default = false;
        };
      };
    });
  };
  config.specialisation =
    mapAttrs' (name: _: (nameValuePair name {
      configuration = {
        myOpt.specialisation.${name}.inside = mkForce true;
      };
    }))
    config.myOpt.specialisation;
}
