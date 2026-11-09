{
  config,
  lib,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.hermes-agent-compose;
  secretKey = name: "${name}/hermes-agent-envFile";
  litellmSecretKey = name: "${name}/litellm-envFile";
in {
  options.myOpt.hermes-agent-compose = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...}: {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        modules = {
          netns = mkOption {
            type = types.anything;
            default = {};
          };
          sleep-on-idle = mkOption {
            type = types.anything;
            default = {};
          };
          squid = mkOption {
            type = types.anything;
            default = {};
          };
          fastcrw = mkOption {
            type = types.anything;
            default = {};
          };
          litellm = mkOption {
            type = types.anything;
            default = {};
          };
          camofox = mkOption {
            type = types.anything;
            default = {};
          };
          searxng = mkOption {
            type = types.anything;
            default = {};
          };
          hermes-agent = mkOption {
            type = types.anything;
            default = {};
          };
        };
        netns-id = mkOption {
          type = types.singleLineStr;
          default = name;
        };
        sleep-on-idle-id = mkOption {
          type = types.singleLineStr;
          default = name;
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    sops.secrets = mkMerge (mapAttrsToList (name: _: {
        ${secretKey name} = {};
        ${litellmSecretKey name} = {};
      })
      enabled);

    users.groups = mkMerge (mapAttrsToList (name: _: let
        hermesCfg = outerCfg.myOpt.hermes-agent.${name};
      in {
        ${hermesCfg.group} = {
          inherit (hermesCfg) gid;
        };
      })
      enabled);

    users.users = mkMerge (mapAttrsToList (name: _: let
        hermesCfg = outerCfg.myOpt.hermes-agent.${name};
      in {
        ${hermesCfg.user} = {
          isSystemUser = true;
          inherit (hermesCfg) uid group;
          home = hermesCfg.stateDir;
        };
      })
      enabled);

    myOpt.netns = mapAttrs' (name: cfg: let
      camofoxCfg = outerCfg.myOpt.camofox.${name};
      fastcrwCfg = outerCfg.myOpt.fastcrw.${name};
    in
      nameValuePair cfg.netns-id (mkMerge [
        cfg.modules.netns
        {
          enable = true;
          set-network-namespace = {
            systemd-services = optional fastcrwCfg.enable fastcrwCfg.serviceName;
            oci-containers = [camofoxCfg.containerName];
            nixos-containers = [cfg.containerName];
          };
        }
      ]))
    enabled;

    myOpt.squid = mapAttrs' (name: cfg:
      nameValuePair name (mkMerge [
        cfg.modules.squid
        {
          enable = true;
          inherit (cfg) netns-id sleep-on-idle-id;
        }
      ]))
    enabled;

    myOpt.camofox = mapAttrs' (name: cfg:
      nameValuePair name (mkMerge [
        cfg.modules.camofox
        {
          enable = true;
        }
      ]))
    enabled;

    myOpt.searxng = mkMerge (mapAttrsToList (name: cfg: {
      })
      enabled);

    myOpt.litellm = mapAttrs' (name: cfg: let
      litellmEnvPath = outerCfg.sops.secrets.${litellmSecretKey name}.path;
    in
      nameValuePair name (mkMerge [
        cfg.modules.litellm
        {
          enable = true;
          container = {
            name = cfg.containerName;
            inherit (cfg) shared-run-dir;
          };
          environmentFile = mkDefault litellmEnvPath;
        }
      ]))
    enabled;

    myOpt.hermes-agent = mapAttrs' (name: cfg: let
      camofoxCfg = outerCfg.myOpt.camofox.${name};
      litellmCfg = outerCfg.myOpt.litellm.${name};
      fastcrwCfg = outerCfg.myOpt.fastcrw.${name};
      hermesEnvPath = outerCfg.sops.secrets.${secretKey name}.path;
    in
      nameValuePair name (mkMerge [
        cfg.modules.hermes-agent
        {
          enable = true;
          container = {
            name = cfg.containerName;
            inherit (cfg) shared-run-dir;
          };
          settings = {
            model.base_url = mkDefault "${litellmCfg.url}/v1";
          };
          environment =
            {
              CAMOFOX_URL = mkDefault camofoxCfg.url;
            }
            // optionalAttrs fastcrwCfg.enable {
              FIRECRAWL_API_URL = mkDefault fastcrwCfg.url;
            };
          environmentFiles = [hermesEnvPath];
        }
      ]))
    enabled;

    myOpt.fastcrw = mapAttrs' (name: cfg: let
      camofoxCfg = outerCfg.myOpt.camofox.${name};
      searxngCfg = outerCfg.myOpt.searxng.${name};
    in
      nameValuePair name (mkMerge [
        {
          enable = mkDefault (cfg.modules.fastcrw != {});
          environment =
            {
              CRW_RENDERER__CAMOUFOX__BASE_URL = mkDefault camofoxCfg.url;
              CRW_RENDERER__CAMOUFOX__INCLUDE_IN_AUTO = mkDefault "true";
            }
            // optionalAttrs (cfg.modules.searxng.enable or false) {
              CRW_SEARCH__SEARCH_BACKEND_URL = mkDefault searxngCfg.url;
            };
        }
        cfg.modules.fastcrw
      ]))
    enabled;

    myOpt.sleep-on-idle = mapAttrs' (name: cfg: let
      hermesCfg = outerCfg.myOpt.hermes-agent.${name};
      litellmCfg = outerCfg.myOpt.litellm.${name};
      camofoxCfg = outerCfg.myOpt.camofox.${name};
      fastcrwCfg = outerCfg.myOpt.fastcrw.${name};
    in
      nameValuePair cfg.sleep-on-idle-id (mkMerge [
        cfg.modules.sleep-on-idle
        {
          enable = true;
          health-check.path = "/";
          endpoints = {
            default = {
              origin.ip-socket = hermesCfg.unix-socket;
              proxy = {inherit (hermesCfg) host port;};
            };
            litellm = {
              origin.ip-socket = litellmCfg.unix-socket;
              proxy = {inherit (litellmCfg) host port;};
            };
          };
          set-cgroup-parent = {
            systemd-services = optional fastcrwCfg.enable fastcrwCfg.serviceName;
            oci-containers = [camofoxCfg.containerName];
            nixos-containers = [cfg.containerName];
          };
        }
      ]))
    enabled;

    containers = mkMerge (mapAttrsToList (name: cfg: let
        hermesCfg = outerCfg.myOpt.hermes-agent.${name};
        litellmCfg = outerCfg.myOpt.litellm.${name};
        hermesEnvPath = outerCfg.sops.secrets.${secretKey name}.path;
        litellmEnvPath = outerCfg.sops.secrets.${litellmSecretKey name}.path;
      in {
        ${cfg.containerName} = {
          ephemeral = true;
          privateNetwork = false;
          privateUsers = "no";
          autoStart = false;
          bindMounts =
            {
              ${hermesCfg.stateDir} = {
                hostPath = hermesCfg.stateDir;
                isReadOnly = false;
              };
              ${litellmCfg.stateDir} = {
                hostPath = litellmCfg.stateDir;
                isReadOnly = false;
              };
              ${cfg.shared-run-dir} = {
                hostPath = cfg.shared-run-dir;
                isReadOnly = false;
              };
            }
            // genAttrs (unique [
              (builtins.dirOf hermesEnvPath)
              (builtins.dirOf litellmEnvPath)
            ]) (dir: {
              hostPath = dir;
              isReadOnly = true;
            });
        };
      })
      enabled);

    systemd.services = mkMerge (mapAttrsToList (name: cfg: let
        camofoxCfg = outerCfg.myOpt.camofox.${name};
        searxngCfg = outerCfg.myOpt.searxng.${name};
        fastcrwCfg = outerCfg.myOpt.fastcrw.${name};
      in {
        ${cfg.serviceName} = {
          wants =
            [
              "${camofoxCfg.serviceName}.service"
            ]
            ++ optional (cfg.modules.searxng.enable or false) "${searxngCfg.serviceName}.service"
            ++ optional fastcrwCfg.enable "${fastcrwCfg.serviceName}.service";
        };
      })
      enabled);

    systemd.tmpfiles.rules = flatten (
      mapAttrsToList (name: cfg: let
        hermesCfg = outerCfg.myOpt.hermes-agent.${name};
        litellmCfg = outerCfg.myOpt.litellm.${name};
      in [
        "d '${hermesCfg.stateDir}' 2770 ${hermesCfg.user} ${hermesCfg.group} - -"
        "d '${litellmCfg.stateDir}' 0750 - - - -"
        "d '${cfg.shared-run-dir}' 2770 ${hermesCfg.user} ${hermesCfg.group} - -"
      ])
      enabled
    );
  };
}
