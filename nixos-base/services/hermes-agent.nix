{
  config,
  lib,
  inputs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.hermes-agent-compose;
  toSliceName = p:
    removeSuffix ".slice" p;
  toSliceUnit = p:
    if p == null
    then null
    else if hasSuffix ".slice" p
    then p
    else "${p}.slice";
in {
  imports = [
    ./netns.nix
    ./camofox.nix
    ./litellm.nix
    ./fastcrw.nix
    ./qdrant.nix
  ];

  options.myOpt.hermes-agent-compose = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        sleep-on-idle = mkOption {
          type = types.anything;
          default = {};
        };
        containerName = mkOption {
          type = types.singleLineStr;
          default = name;
          readOnly = true;
        };
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "container@${cfg.containerName}";
          readOnly = true;
        };
        # Dedicated non-templated slice name (avoids invalid `container@<name>.slice`).
        # Inspect with: `systemctl status ${cfg.sliceName}.slice`
        sliceName = mkOption {
          type = types.singleLineStr;
          default = "hermes-agent-${name}";
        };
        cgroup-parent = mkOption {
          type = types.nullOr types.singleLineStr;
          default = "${cfg.sliceName}.slice";
        };
        networkNamespace = mkOption {
          type = types.nullOr types.singleLineStr;
          default = name;
        };
        netns = {
          ipv6-only = mkOption {
            type = types.bool;
            default = false;
          };
          wireguard = {
            enable = mkOption {
              type = types.bool;
              default = false;
            };
          };
        };
        sopsFile = mkOption {
          type = types.anything;
        };
        secretsDirName = mkOption {
          type = types.singleLineStr;
          default = name;
          readOnly = true;
        };
        socketDir = mkOption {
          type = types.singleLineStr;
          default = "/run/sockets/${name}";
          readOnly = true;
        };
        secretsDir = mkOption {
          type = types.singleLineStr;
          default = builtins.dirOf outerCfg.sops.secrets.${cfg.hermes-agent.envFile-key}.path;
          readOnly = true;
        };
        # Host interactive user who joins the hermes group outside the container
        user = mkOption {
          type = types.nullOr types.singleLineStr;
          default = null;
        };
        hermes-agent = {
          user = mkOption {
            type = types.singleLineStr;
            default = "hermes-${name}";
          };
          group = mkOption {
            type = types.singleLineStr;
            default = "hermes-${name}";
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
          port = mkOption {
            type = types.port;
          };
          envFile-key = mkOption {
            type = types.singleLineStr;
            default = "${cfg.secretsDirName}/hermes-agent-envFile";
            readOnly = true;
          };
          unix-socket = mkOption {
            type = types.singleLineStr;
            default = "${cfg.socketDir}/hermes-agent.sock";
            readOnly = true;
          };
          host = mkOption {
            type = types.singleLineStr;
            default = "::1";
            readOnly = true;
          };
          settings = mkOption {
            type = types.anything;
            default = {};
            apply = userSettings:
              recursiveUpdate {
                web = {
                  backend = "firecrawl";
                  search_backend = "firecrawl";
                  extract_backend = "firecrawl";
                };
                browser.cloud_provider = "camofox";
                display.busy_input_mode = "steer";
                model = {
                  default = "";
                  provider = "openai";
                  base_url = "${outerCfg.myOpt.litellm.${name}.url}/v1";
                  api_mode = "";
                };
                agent = {
                  reasoning_effort = "none"; # most efficient
                  service_tier = "";
                };
                telemetry.shared_metrics = {
                  enabled = true;
                  send = true;
                };
                moa.presets.default.enabled = false;
              }
              userSettings;
          };
        };
        camofox = {
          image = mkOption {
            type = types.singleLineStr;
            example = "ghcr.io/jo-inc/camofox-browser:1.18.1";
          };
          port = mkOption {
            type = types.port;
            default = 11982;
          };
        };
        litellm = {
          stateDir = mkOption {
            type = types.singleLineStr;
          };
          port = mkOption {
            type = types.port;
          };
          settings = mkOption {
            type = types.anything;
            default = {};
          };
        };
        fastcrw = {
          enable = mkOption {
            type = types.bool;
            default = true;
          };
          image = mkOption {
            type = types.singleLineStr;
            default = "ghcr.io/fastcrw/crw:latest";
          };
          port = mkOption {
            type = types.port;
            default = 21023;
          };
          searxng = {
            enable = mkOption {
              type = types.bool;
              default = true;
            };
            port = mkOption {
              type = types.port;
              default = 8080;
            };
          };
        };
        qdrant = {
          enable = mkOption {
            type = types.bool;
            default = true;
          };
          image = mkOption {
            type = types.singleLineStr;
            default = "docker.io/qdrant/qdrant:latest";
          };
          stateDir = mkOption {
            type = types.singleLineStr;
          };
          httpPort = mkOption {
            type = types.port;
            default = 6333;
          };
          grpcPort = mkOption {
            type = types.port;
            default = 6334;
          };
          collectionName = mkOption {
            type = types.singleLineStr;
            default = "hermes-${name}";
          };
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    sops.secrets = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.hermes-agent.envFile-key} = {inherit (cfg) sopsFile;};
      })
      enabled);

    # ── Host-side matching user/group + host interactive user membership ──
    users.groups = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.hermes-agent.group} = {
          inherit (cfg.hermes-agent) gid;
        };
      })
      enabled);

    users.users = mkMerge (mapAttrsToList (_: cfg:
      {
        ${cfg.hermes-agent.user} = {
          isSystemUser = true;
          inherit (cfg.hermes-agent) uid group;
          home = cfg.hermes-agent.stateDir;
        };
      }
      // optionalAttrs (cfg.user != null) {
        ${cfg.user}.extraGroups = [cfg.hermes-agent.group];
      })
    enabled);

    # ── Compose extracted modules ─────────────────────────────────────────
    myOpt.netns = mkMerge (mapAttrsToList (
        name: cfg:
          optionalAttrs (cfg.networkNamespace == name) {
            ${name} = {
              enable = true;
              inherit (cfg.netns) ipv6-only;
              wireguard = {
                inherit (cfg.netns.wireguard) enable;
                sopsFile =
                  if cfg.netns.wireguard.enable
                  then cfg.sopsFile
                  else null;
                secretsDirName = cfg.secretsDirName;
              };
            };
          }
      )
      enabled);

    myOpt.camofox-compose = mkMerge (mapAttrsToList (name: cfg: {
        ${name} = {
          enable = true;
          inherit (cfg.camofox) image port;
          inherit (cfg) sopsFile secretsDirName cgroup-parent networkNamespace;
        };
      })
      enabled);

    myOpt.litellm = mkMerge (mapAttrsToList (name: cfg: {
        ${name} = {
          enable = true;
          inherit (cfg.litellm) stateDir port settings;
          inherit
            (cfg)
            socketDir
            sopsFile
            secretsDirName
            cgroup-parent
            networkNamespace
            ;
        };
      })
      enabled);

    myOpt.fastcrw = mkMerge (mapAttrsToList (name: cfg: {
        ${name} = {
          inherit (cfg.fastcrw) enable image port;
          inherit (cfg) sopsFile secretsDirName cgroup-parent networkNamespace;
          camofox = {
            enable = true;
            url = outerCfg.myOpt.camofox-compose.${name}.url;
            includeInAuto = true;
          };
          searxng = {
            inherit (cfg.fastcrw.searxng) enable port;
          };
        };
      })
      enabled);

    myOpt.qdrant = mkMerge (mapAttrsToList (name: cfg: {
        ${name} = {
          inherit (cfg.qdrant) enable image stateDir httpPort grpcPort;
          inherit (cfg) sopsFile secretsDirName cgroup-parent networkNamespace;
        };
      })
      enabled);

    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (name: cfg: let
        camofoxCfg = outerCfg.myOpt.camofox-compose.${name};
        litellmCfg = outerCfg.myOpt.litellm.${name};
        fastcrwCfg = outerCfg.myOpt.fastcrw.${name};
        qdrantCfg = outerCfg.myOpt.qdrant.${name};
      in {
        ${cfg.serviceName} = mkMerge [
          cfg.sleep-on-idle
          {
            dependsOn =
              [
                camofoxCfg.serviceName
                litellmCfg.serviceName
              ]
              ++ optionals cfg.fastcrw.enable (
                [fastcrwCfg.serviceName]
                ++ optional cfg.fastcrw.searxng.enable fastcrwCfg.searxng.serviceName
              )
              ++ optional cfg.qdrant.enable qdrantCfg.serviceName;
            health-check.path = "/";
            endpoints = {
              default = {
                origin.ip-socket = cfg.hermes-agent.unix-socket;
                proxy = {inherit (cfg.hermes-agent) host port;};
              };
              litellm = {
                origin.ip-socket = litellmCfg.unix-socket;
                proxy = {inherit (litellmCfg) host port;};
              };
            };
          }
        ];
      })
      enabled);

    containers = mkMerge (mapAttrsToList (name: cfg: let
        camofoxCfg = outerCfg.myOpt.camofox-compose.${name};
        fastcrwCfg = outerCfg.myOpt.fastcrw.${name};
        qdrantCfg = outerCfg.myOpt.qdrant.${name};
        netnsCfg =
          if cfg.networkNamespace != null
          then outerCfg.myOpt.netns.${cfg.networkNamespace} or null
          else null;
        nsPath =
          if netnsCfg != null
          then netnsCfg.path
          else "/run/netns/${cfg.networkNamespace}";
        nsResolvConf =
          if netnsCfg != null
          then netnsCfg.resolvConf
          else "/etc/netns/${cfg.networkNamespace}/resolv.conf";
      in {
        ${cfg.containerName} = {
          ephemeral = true;
          privateNetwork = false;
          networkNamespace =
            if cfg.networkNamespace != null
            then nsPath
            else null;
          autoStart = false;
          bindMounts =
            {
              ${cfg.hermes-agent.stateDir} = {
                hostPath = cfg.hermes-agent.stateDir;
                isReadOnly = false;
              };
              ${cfg.secretsDir} = {
                hostPath = cfg.secretsDir;
                isReadOnly = true;
              };
              ${cfg.socketDir} = {
                hostPath = cfg.socketDir;
                isReadOnly = false;
              };
            }
            // optionalAttrs (cfg.networkNamespace != null) {
              "/etc/resolv.conf" = {
                hostPath = nsResolvConf;
                isReadOnly = true;
              };
            };
          config = {...}: {
            imports = [
              inputs.hermes-agent.nixosModules.default
              ../../myLib
              ../systemd-socket-proxyd.nix
            ];
            users.groups.${cfg.hermes-agent.group}.gid = cfg.hermes-agent.gid;
            users.users.${cfg.hermes-agent.user}.uid = cfg.hermes-agent.uid;

            myOpt.systemd-socket-proxyd = {
              hermes-agent = {
                origin = {inherit (cfg.hermes-agent) host port;};
                proxy.ip-socket = cfg.hermes-agent.unix-socket;
              };
            };
            services.hermes-agent = {
              inherit (cfg.hermes-agent) user group stateDir settings;
              enable = true;
              # Ensures config.yaml mode is 0660 so host group members can also write config
              addToSystemPackages = true;
              backend = {
                inherit (cfg.hermes-agent) host port;
                mode = "serve";
              };
              mcpServers = optionalAttrs cfg.qdrant.enable {
                qdrant = {
                  command = "uvx";
                  args = ["mcp-server-qdrant"];
                  env = {
                    QDRANT_URL = qdrantCfg.httpUrl;
                    COLLECTION_NAME = cfg.qdrant.collectionName;
                    FASTEMBED_CACHE_PATH = "${cfg.hermes-agent.stateDir}/fastembed-cache";
                  };
                };
              };
              environment =
                {
                  CAMOFOX_URL = camofoxCfg.url;
                }
                // optionalAttrs cfg.fastcrw.enable {
                  FIRECRAWL_API_URL = fastcrwCfg.url;
                };
              environmentFiles = [outerCfg.sops.secrets.${cfg.hermes-agent.envFile-key}.path];
            };
          };
        };
      })
      enabled);

    systemd.slices = mkMerge (mapAttrsToList (
        _: cfg:
          optionalAttrs (cfg.cgroup-parent != null) {
            ${toSliceName cfg.cgroup-parent} = {};
          }
      )
      enabled);

    systemd.services = mkMerge (mapAttrsToList (name: cfg: let
        camofoxCfg = outerCfg.myOpt.camofox-compose.${name};
        litellmCfg = outerCfg.myOpt.litellm.${name};
        fastcrwCfg = outerCfg.myOpt.fastcrw.${name};
        qdrantCfg = outerCfg.myOpt.qdrant.${name};
        sliceUnit = toSliceUnit cfg.cgroup-parent;
        netnsCfg =
          if cfg.networkNamespace != null
          then outerCfg.myOpt.netns.${cfg.networkNamespace} or null
          else null;
        nsUnit =
          if netnsCfg != null
          then netnsCfg.unit
          else "${cfg.networkNamespace}.service";
      in {
        ${cfg.serviceName} = mkMerge [
          {
            wants =
              [
                "${camofoxCfg.serviceName}.service"
                "${litellmCfg.serviceName}.service"
              ]
              ++ optionals cfg.fastcrw.enable (
                ["${fastcrwCfg.serviceName}.service"]
                ++ optional cfg.fastcrw.searxng.enable "${fastcrwCfg.searxng.serviceName}.service"
              )
              ++ optional cfg.qdrant.enable "${qdrantCfg.serviceName}.service";
          }
          (mkIf (cfg.networkNamespace != null) {
            bindsTo = [nsUnit];
            after = [nsUnit];
          })
          (mkIf (sliceUnit != null) {
            serviceConfig.Slice = mkForce sliceUnit;
          })
        ];
      })
      enabled);

    systemd.tmpfiles.rules = flatten (
      mapAttrsToList (_: cfg: [
        "d '${cfg.hermes-agent.stateDir}' 2770 ${cfg.hermes-agent.user} ${cfg.hermes-agent.group} - -"
        "d '${cfg.socketDir}' 2770 ${cfg.hermes-agent.user} ${cfg.hermes-agent.group} - -"
      ])
      enabled
    );
  };
}
