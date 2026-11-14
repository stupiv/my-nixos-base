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
        modules = {
          services.postgresql = mkOption {
            type = types.anything;
            # type = types.submodule ({...}: {
            #   freeformType = types.anything;
            #   options = {
            #     package = mkOption {
            #       type = types.anything;
            #     };
            #     settings.port = mkOption {
            #       type = types.anything;
            #     };
            #   };
            # });
          };
        };
        # container = mkOption {
        #   type = types.submodule ({...}: {
        #     freeformType = types.anything;
        #     options = {};
        #   });
        # };
        # stateDir = mkOption {
        #   type = types.anything;
        #   default = "${cfg.container.stateDir}/postgresql";
        #   readOnly = true;
        # };
        container.name = mkOption {
          type = types.singleLineStr;
        };
        stateDir = mkOption {
          type = types.singleLineStr;
        };
        sleep-on-idle-id = mkOption {
          type = types.nullOr types.singleLineStr;
        };
        netns-id = mkOption {
          type = types.nullOr types.singleLineStr;
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: let
        inherit (outerCfg.ids) uids gids;
      in [
        "d '${cfg.stateDir}' 0700 ${toString uids.postgres} ${toString gids.postgres} - -"
      ])
      enabled);

    containers = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.container.name} = {
          extraFlags = [
            "--bind=${cfg.stateDir}:${cfg.stateDir}:idmap"
          ];
          config = {...}: {
            services.postgresql = mkMerge [
              cfg.modules.services.postgresql
              {
                enable = true;
                package = mkDefault cfg.modules.services.postgresql.package;
                dataDir = cfg.stateDir;
                settings = {
                  inherit (cfg.modules.services.postgresql.settings) port;
                };
              }
            ];
          };
        };
      })
      enabled);

    myOpt.netns = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.netns-id}.set-network-namespace = {
          nixos-containers = [cfg.container.name];
        };
      })
      (filterAttrs (_: cfg: cfg.netns-id != null) enabled));

    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.sleep-on-idle-id}.set-cgroup-parent = {
          nixos-containers = [cfg.container.name];
        };
      })
      (filterAttrs (_: cfg: cfg.sleep-on-idle-id != null) enabled));
  };
}
