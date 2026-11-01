{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  enabled = filterAttrs (_: cfg: cfg.enable) config.myOpt.valkey;
in {
  options.myOpt.valkey = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({
      name,
      config,
      ...
    }: {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        modules.services.redis = mkOption {
          type = types.anything;
          default = {};
        };
        container = mkOption {
          type = types.anything;
          default = {};
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    containers = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.container.name}.config = {...}: {
          services.redis = mkMerge [
            cfg.modules.services.redis
            {
              enable = true;
              package = mkDefault cfg.modules.services.redis.package;
            }
          ];
        };
      })
      enabled);
  };
}
