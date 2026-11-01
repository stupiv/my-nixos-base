{
  config,
  lib,
  ...
}:
with lib; let
  enabled = filterAttrs (_: cfg: cfg.enable) config.myOpt.mariadb;
in {
  options.myOpt.mariadb = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({config, ...}: {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        modules.services.mysql = mkOption {
          type = types.anything;
          default = {};
        };
        container = mkOption {
          type = types.anything;
          default = {};
        };
        stateDir = mkOption {
          type = types.singleLineStr;
          default = "${config.container.stateDir}/mariadb";
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    containers = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.container.name}.config = {...}: {
          services.mysql = mkMerge [
            cfg.modules.services.mysql
            {
              enable = true;
              package = mkDefault cfg.modules.services.mysql.package;
              dataDir = cfg.stateDir;
            }
          ];
        };
      })
      enabled);
  };
}
