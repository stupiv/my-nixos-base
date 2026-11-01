{
  config,
  lib,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.postgresql;
in {
  options.myOpt.postgresql = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        modules.services.postgresql = mkOption {
          type = types.anything;
          default = {};
        };
        container = mkOption {
          type = types.anything;
          default = {};
        };
        stateDir = mkOption {
          type = types.anything;
          default = "${cfg.container.stateDir}/postgresql";
          readOnly = true;
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    containers = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.container.name}.config = {...}: {
          systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: [
              "d '${cfg.stateDir}' 0700 postgres postgres - -"
            ])
            enabled);
          services.postgresql = mkMerge [
            cfg.modules.services.postgresql
            {
              enable = true;
              package = mkDefault cfg.modules.services.postgresql.package;
              dataDir = cfg.stateDir;
            }
          ];
        };
      })
      enabled);
  };
}
