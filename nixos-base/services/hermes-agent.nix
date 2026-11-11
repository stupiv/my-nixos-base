{
  config,
  lib,
  inputs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.hermes-agent;
in {
  options.myOpt.hermes-agent = mkOption {
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
          services.hermes-agent = mkOption {
            type = types.anything;
          };
        };
        container.name = mkOption {
          type = types.singleLineStr;
        };
        hermes-agent-cfg = mkOption {
          type = types.anything;
          default = outerCfg.containers.${cfg.container.name}.config.services.hermes-agent;
          readOnly = true;
        };
        host = mkOption {
          type = types.anything;
          default = cfg.hermes-agent-cfg.backend.host;
          readOnly = true;
        };
        port = mkOption {
          type = types.anything;
          default = cfg.hermes-agent-cfg.backend.port;
          readOnly = true;
        };
        uid = mkOption {
          type = types.int;
        };
        gid = mkOption {
          type = types.int;
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
        sops.dotenv = {
          key = mkOption {
            type = types.anything;
          };
          sopsFile = mkOption {
            type = types.anything;
          };
          path = mkOption {
            type = types.strMatching "^${cfg.runDir}/.*[^/]$";
            default = "${cfg.runDir}/.env";
          };
        };
        runDir = mkOption {
          type = types.strMatching "^/run/[^/]+/.*[^/]$";
          default = "/run/${name}/camofox";
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    sops.secrets = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.sops.dotenv.key} = {
          inherit (cfg.sops.dotenv) sopsFile path;
        };
      })
      enabled);

    containers = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.container.name} = {
          extraFlags = [
            "--bind=${cfg.stateDir}:${cfg.hermes-agent-cfg.stateDir}:idmap"
            "--bind=${cfg.runDir}:${cfg.runDir}:rootidmap"
          ];
          config = {...}: {
            imports = [
              inputs.hermes-agent.nixosModules.default
            ];
            users.groups.${cfg.hermes-agent-cfg.group}.gid = cfg.gid;
            users.users.${cfg.hermes-agent-cfg.user}.uid = cfg.uid;
            services.hermes-agent = mkMerge [
              cfg.modules.services.hermes-agent
              {
                enable = true;
                package = mkDefault cfg.modules.services.hermes-agent.package;
                environmentFiles = [cfg.sops.dotenv.path];
                backend = {
                  inherit (cfg.modules.services.hermes-agent.backend) port;
                  mode = mkDefault "serve";
                  host = mkDefault "::1";
                };
              }
            ];
          };
        };
      })
      enabled);

    myOpt.netns = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.netns-id}.set-network-namespace = {
          nixos-containers = [
            cfg.container.name
          ];
        };
      })
      (filterAttrs (_: cfg: cfg.netns-id != null) enabled));

    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.sleep-on-idle-id}.set-cgroup-parent = {
          nixos-containers = [
            cfg.container.name
          ];
        };
      })
      (filterAttrs (_: cfg: cfg.sleep-on-idle-id != null) enabled));
  };
}
