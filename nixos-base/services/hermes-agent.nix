{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (name: cfg: cfg.enable) outerCfg.myOpt.hermes-agent;
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
          type = types.singleLineStr;
          default = cfg.hermes-agent-cfg.backend.host;
          readOnly = true;
        };
        port = mkOption {
          type = types.port;
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
            type = types.singleLineStr;
          };
          sopsFile = mkOption {
            type = types.path;
          };
          path = mkOption {
            type = types.strMatching "^/run/.*[^/]$";
            default = outerCfg.sops.secrets.${cfg.sops.dotenv.key}.path;
            readOnly = true;
          };
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    sops.useTmpfs = true;
    sops.secrets = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.sops.dotenv.key} = {
          inherit (cfg.sops.dotenv) sopsFile;
          restartUnits = ["container@${name}.service"];
        };
      })
      enabled);

    systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: [
        "d '${cfg.stateDir}' 0711 ${toString cfg.uid} ${toString cfg.gid} - -"
      ])
      enabled);

    containers = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.container.name} = {
          extraFlags = [
            "--bind=${cfg.stateDir}:${cfg.stateDir}:idmap"
            "--bind-ro=${cfg.sops.dotenv.path}:${cfg.sops.dotenv.path}:rootidmap"
          ];
          config = {...}: {
            imports = [
              inputs.hermes-agent.nixosModules.default
            ];

            programs.nix-ld.enable = false;

            users.users.${cfg.hermes-agent-cfg.user}.uid = cfg.uid;
            users.groups.${cfg.hermes-agent-cfg.group}.gid = cfg.gid;
            services.hermes-agent = mkMerge [
              cfg.modules.services.hermes-agent
              {
                enable = true;
                inherit (cfg) stateDir;
                package = mkDefault cfg.modules.services.hermes-agent.package;
                environmentFiles = [cfg.sops.dotenv.path];
                backend = {
                  inherit (cfg.modules.services.hermes-agent.backend) port;
                  host = mkDefault "::1";
                  mode = mkDefault "serve";
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
      (filterAttrs (name: cfg: cfg.netns-id != null) enabled));

    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.sleep-on-idle-id}.set-cgroup-parent = {
          nixos-containers = [
            cfg.container.name
          ];
        };
      })
      (filterAttrs (name: cfg: cfg.sleep-on-idle-id != null) enabled));
  };
}
