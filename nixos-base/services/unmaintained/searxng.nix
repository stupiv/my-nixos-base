{
  config,
  lib,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.searxng;
in {
  options.myOpt.searxng = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({...}: {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        modules.services.searx = mkOption {
          default = {};
          type = types.submodule ({...}: {
            freeformType = types.anything;
            options = {
              package = mkOption {
                type = types.anything;
              };
              settings.server.port = mkOption {
                type = types.anything;
              };
            };
          });
        };
        netns-id = mkOption {
          type = types.singleLineStr;
        };
        sleep-on-idle-id = mkOption {
          type = types.singleLineStr;
        };
        container = mkOption {
          default = {};
          type = types.submodule ({...}: {
            freeformType = types.anything;
            options = {};
          });
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    containers = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.container.name}.config = {...}: {
          services.searx = mkMerge [
            (removeAttrs cfg.modules.services.searx ["_module"])
            {
              enable = true;
            }
          ];
        };
      })
      enabled);
  };
}
