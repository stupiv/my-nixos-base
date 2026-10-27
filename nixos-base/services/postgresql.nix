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
        container = mkOption {
          type = types.anything;
          default = {};
        };
        stateDir = mkOption {
          type = types.anything;
          default = "${cfg.container.stateDir}/postgresql";
          readOnly = true;
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
            systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: [
                "d '${cfg.stateDir}' 0700 postgres postgres - -"
              ])
              enabled);
            services.postgresql = mkMerge [
              cfg.postgresql
              {
                enable = true;
                package = mkDefault cfg.postgresql.package;
                dataDir = cfg.stateDir;
              }
            ];
          };
        };
      })
      enabled);
  };
}
