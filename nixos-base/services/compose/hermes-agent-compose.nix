{
  config,
  lib,
  inputs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.hermes-agent-compose;
  secretKey = name: "${name}/hermes-agent-envFile";
  mkHttpUrl = host: port: let
    bracketedHost =
      if hasPrefix "[" host
      then host
      else if hasInfix ":" host
      then "[${host}]"
      else host;
  in "http://${bracketedHost}:${toString port}";
  toSliceName = p: removeSuffix ".slice" p;
  toSliceUnit = p:
    if p == null
    then null
    else if hasSuffix ".slice" p
    then p
    else "${p}.slice";
in {
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
          type = types.nullOr types.anything;
          default = null;
        };
        socketDir = mkOption {
          type = types.singleLineStr;
          default = "/run/sockets/${name}";
          readOnly = true;
        };
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
          url = mkOption {
            type = types.singleLineStr;
            default = mkHttpUrl cfg.hermes-agent.host cfg.hermes-agent.port;
          };
          telemetry = mkOption {
            type = types.bool;
            default = true;
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
                  reasoning_effort = "none";
                  service_tier = "";
                };
                telemetry.shared_metrics = {
                  enabled = cfg.hermes-agent.telemetry;
                  send = cfg.hermes-agent.telemetry;
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
          };
          telemetry = mkOption {
            type = types.bool;
            default = true;
          };
        };
        searxng = {
          enable = mkOption {
            type = types.bool;
            default = true;
          };
          image = mkOption {
            type = types.singleLineStr;
            example = "docker.io/searxng/searxng:2026.5.9-0cba32c15";
          };
          port = mkOption {
            type = types.port;
          };
          settings = mkOption {
            type = types.anything;
            default = {};
          };
        };
        litellm = {
          stateDir = mkOption {
            type = types.singleLineStr;
          };
          port = mkOption {
            type = types.port;
          };
          telemetry = mkOption {
            type = types.bool;
            default = true;
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
          port = mkOption {
            type = types.port;
          };
          environment = mkOption {
            type = types.attrsOf types.str;
            default = {};
          };
        };
        qdrant = {
          enable = mkOption {
            type = types.bool;
            default = true;
          };
          stateDir = mkOption {
            type = types.singleLineStr;
          };
          httpPort = mkOption {
            type = types.port;
          };
          grpcPort = mkOption {
            type = types.port;
          };
          telemetry = mkOption {
            type = types.bool;
            default = true;
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
    sops.secrets = mkMerge (mapAttrsToList (name: cfg: {
        ${secretKey name} = optionalAttrs (cfg.sopsFile != null) {
          inherit (cfg) sopsFile;
        };
      })
      enabled);

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

    myOpt.netns = mkMerge (mapAttrsToList (
        name: cfg:
          optionalAttrs (cfg.networkNamespace == name) {
            ${name} = {
              enable = true;
              inherit (cfg) sopsFile;
              inherit (cfg.netns) ipv6-only;
              wireguard = {
                inherit (cfg.netns.wireguard) enable;
              };
            };
          }
      )
      enabled);

    myOpt.camofox-compose = mkMerge (mapAttrsToList (name: cfg: {
        ${name} = {
          enable = true;
          inherit (cfg.camofox) image port telemetry;
          inherit (cfg) sopsFile cgroup-parent networkNamespace;
        };
      })
      enabled);

    myOpt.searxng-compose = mkMerge (mapAttrsToList (name: cfg: {
        ${name} = {
          inherit (cfg.searxng) enable image port settings;
          inherit (cfg) sopsFile cgroup-parent networkNamespace;
        };
      })
      enabled);

    myOpt.litellm = mkMerge (mapAttrsToList (name: cfg: {
        ${name} = {
          enable = true;
          inherit (cfg.litellm) stateDir port telemetry settings;
          inherit (cfg) socketDir sopsFile cgroup-parent networkNamespace;
        };
      })
      enabled);

    myOpt.fastcrw = mkMerge (mapAttrsToList (name: cfg: let
        camofoxCfg = outerCfg.myOpt.camofox-compose.${name};
        searxngCfg = outerCfg.myOpt.searxng-compose.${name};
      in {
        ${name} = {
          inherit (cfg.fastcrw) enable port;
          inherit (cfg) sopsFile cgroup-parent networkNamespace;
          environment =
            {
              CRW_RENDERER__CAMOUFOX__BASE_URL = camofoxCfg.url;
              CRW_RENDERER__CAMOUFOX__INCLUDE_IN_AUTO = "true";
            }
            // optionalAttrs cfg.searxng.enable {
              CRW_SEARCH__SEARCH_BACKEND_URL = searxngCfg.url;
            }
            // cfg.fastcrw.environment;
        };
      })
      enabled);

    myOpt.qdrant = mkMerge (mapAttrsToList (name: cfg: {
        ${name} = {
          inherit (cfg.qdrant) enable stateDir httpPort grpcPort telemetry;
          inherit (cfg) sopsFile cgroup-parent networkNamespace;
        };
      })
      enabled);

    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (name: cfg: let
        litellmCfg = outerCfg.myOpt.litellm.${name};
      in {
        ${cfg.serviceName} = mkMerge [
          cfg.sleep-on-idle
          {
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
          (optionalAttrs (cfg.cgroup-parent != null) {
            inherit (cfg) cgroup-parent;
          })
        ];
      })
      enabled);

    containers = mkMerge (mapAttrsToList (name: cfg: let
        camofoxCfg = outerCfg.myOpt.camofox-compose.${name};
        fastcrwCfg = outerCfg.myOpt.fastcrw.${name};
        qdrantCfg = outerCfg.myOpt.qdrant.${name};
        envPath = outerCfg.sops.secrets.${secretKey name}.path;
        secretsDir = builtins.dirOf envPath;
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
          privateUsers = "no";
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
              ${secretsDir} = {
                hostPath = secretsDir;
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
                }
                // optionalAttrs cfg.qdrant.enable {
                  QDRANT_URL = qdrantCfg.httpUrl;
                };
              environmentFiles = [envPath];
            };
            systemd.services.hermes-agent.serviceConfig = {
              NoNewPrivileges = true;
              PrivateTmp = true;
              PrivateDevices = true;
              ProtectSystem = "strict";
              ProtectHome = true;
              ProtectClock = true;
              ProtectControlGroups = true;
              ProtectHostname = true;
              ProtectKernelLogs = true;
              ProtectKernelModules = true;
              ProtectKernelTunables = true;
              ProtectProc = "invisible";
              ReadWritePaths = [cfg.hermes-agent.stateDir];
              CapabilityBoundingSet = "";
              AmbientCapabilities = "";
              LockPersonality = true;
              RestrictAddressFamilies = [
                "AF_INET"
                "AF_INET6"
                "AF_UNIX"
              ];
              RestrictNamespaces = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              SystemCallArchitectures = "native";
              SystemCallFilter = [
                "@system-service"
                "~@privileged"
              ];
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
        searxngCfg = outerCfg.myOpt.searxng-compose.${name};
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
              ++ optional cfg.searxng.enable "${searxngCfg.serviceName}.service"
              ++ optional cfg.fastcrw.enable "${fastcrwCfg.serviceName}.service"
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
