{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.set-env-vars;
in {
  options.myOpt.set-env-vars = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        environment = mkOption {
          type = types.attrsOf types.singleLineStr;
        };
        systemd-services = mkOption {
          type = types.listOf types.singleLineStr;
        };
        oci-containers = mkOption {
          type = types.listOf types.singleLineStr;
        };
        nixos-containers = mkOption {
          type = types.listOf types.singleLineStr;
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    systemd.services = mkMerge (mapAttrsToList (_: cfg: (genAttrs cfg.systemd-services (_: {
        inherit (cfg) environment;
      })))
      enabled);

    virtualisation.oci-containers.containers = mkMerge (
      mapAttrsToList (_: cfg: (genAttrs cfg.oci-containers (_: {
        inherit (cfg) environment;
      })))
      enabled
    );

    containers = mkMerge (
      mapAttrsToList (_: cfg: (genAttrs cfg.nixos-containers (_: {
        config.environment.variables = cfg.environment;
      })))
      enabled
    );
  };
}
