{
  config,
  lib,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.postgresql-compose;
in {
  options.myOpt.postgresql-compose = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        container = {
          type = types.anything;
          default = {};
        };
        postgresql = mkOption {
          type = types.anything;
          default = {};
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    containers = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.container.name} = {
          config = {...}: {
            services.postgresql = mkMerge [
              cfg.postgresql
              {
                inherit (cfg.postgresql) package;
                enable = true;
                dataDir = "${cfg.container.stateDir}/postgresql";
              }
            ];
          };
        };
      })
      enabled);
  };
}
