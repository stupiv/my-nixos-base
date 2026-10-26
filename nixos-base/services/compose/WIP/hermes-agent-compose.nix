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
        modules = {
          netns = mkOption {
            type = types.anything;
            default = {};
          };
          sleep-on-idle = mkOption {
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
        };
        telemetry = mkOption {
          type = types.bool;
          default = true;
        };
        hermes-agent = {
          extra-users = mkOption {
            type = types.listOf types.singleLineStr;
          };
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
            default = "${cfg.shared-run-dir}/hermes-agent.sock";
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
                  reasoning_effort = "none";
                  service_tier = "";
                };
                telemetry.shared_metrics = {
                  enabled = cfg.telemetry;
                  send = cfg.telemetry;
                };
                moa.presets.default.enabled = false;
              }
              userSettings;
          };
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    sops.secrets = mkMerge (mapAttrsToList (name: cfg: {
      })
      enabled);

    users.groups = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.hermes-agent.group} = {
          inherit (cfg.hermes-agent) gid;
        };
      })
      enabled);

    users.users = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.hermes-agent.user} = {
          isSystemUser = true;
          inherit (cfg.hermes-agent) uid group;
          home = cfg.hermes-agent.stateDir;
        };
      })
      enabled);

    myOpt.netns = mkMerge (mapAttrsToList (
        name: cfg: {
        }
      )
      enabled);

    myOpt.camofox = mkMerge (mapAttrsToList (name: cfg: {
      })
      enabled);

    myOpt.searxng = mkMerge (mapAttrsToList (name: cfg: {
      })
      enabled);

    myOpt.litellm = mkMerge (mapAttrsToList (name: cfg: {
      })
      enabled);

    myOpt.fastcrw = mkMerge (mapAttrsToList (name: cfg: let
        camofoxCfg = outerCfg.myOpt.camofox.${name};
        searxngCfg = outerCfg.myOpt.searxng.${name};
      in {
        ${name} = {
          environment =
            {
              CRW_RENDERER__CAMOUFOX__BASE_URL = camofoxCfg.url;
              CRW_RENDERER__CAMOUFOX__INCLUDE_IN_AUTO = "true";
            }
            // optionalAttrs cfg.modules.searxng.enable {
              CRW_SEARCH__SEARCH_BACKEND_URL = searxngCfg.url;
            }
            // cfg.fastcrw.environment;
        };
      })
      enabled);

    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (name: cfg: let
        litellmCfg = outerCfg.myOpt.litellm.${name};
      in {
        ${cfg.serviceName} = mkMerge [
          cfg.modules.sleep-on-idle
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
        camofoxCfg = outerCfg.myOpt.camofox.${name};
        fastcrwCfg = outerCfg.myOpt.fastcrw.${name};
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
              ${cfg.shared-run-dir} = {
                hostPath = cfg.shared-run-dir;
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
              environment =
                {
                  CAMOFOX_URL = camofoxCfg.url;
                }
                // optionalAttrs cfg.fastcrw.enable {
                  FIRECRAWL_API_URL = fastcrwCfg.url;
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
        camofoxCfg = outerCfg.myOpt.camofox.${name};
        searxngCfg = outerCfg.myOpt.searxng.${name};
        litellmCfg = outerCfg.myOpt.litellm.${name};
        fastcrwCfg = outerCfg.myOpt.fastcrw.${name};
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
              ++ optional cfg.modules.searxng.enable "${searxngCfg.serviceName}.service"
              ++ optional cfg.fastcrw.enable "${fastcrwCfg.serviceName}.service";
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
        "d '${cfg.shared-run-dir}' 2770 ${cfg.hermes-agent.user} ${cfg.hermes-agent.group} - -"
      ])
      enabled
    );
  };
}
