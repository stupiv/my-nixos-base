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
        modules.services.hermes-agent = mkOption {
          type = types.anything;
          default = {};
        };
        container = mkOption {
          type = types.anything;
          default = {};
        };
        extra-users = mkOption {
          type = types.listOf types.singleLineStr;
          default = [];
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
          default = "${cfg.container.shared-run-dir}/hermes-agent.sock";
          readOnly = true;
        };
        host = mkOption {
          type = types.singleLineStr;
          default = "::1";
          readOnly = true;
        };
        environment = mkOption {
          type = types.attrsOf types.str;
          default = {};
        };
        environmentFiles = mkOption {
          type = types.listOf types.str;
          default = [];
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
                provider = "custom";
                api_mode = "";
              };
              agent = {
                reasoning_effort = "none";
                service_tier = "";
              };
              moa.presets.default.enabled = false;
            }
            userSettings;
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    containers = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.container.name}.config = {config, ...}: let
          innerCfg = config;
          serviceHardening = {
            NoNewPrivileges = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectSystem = "strict";
            ProtectHome = mkForce true;
            ProtectClock = true;
            ProtectControlGroups = true;
            ProtectHostname = true;
            ProtectKernelLogs = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            ProtectProc = "invisible";
            ReadWritePaths = [cfg.stateDir];
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
        in {
          imports = [
            inputs.hermes-agent.nixosModules.default
            ./systemd-socket-proxyd.nix
          ];
          users.groups.${cfg.group}.gid = cfg.gid;
          users.users.${cfg.user}.uid = cfg.uid;

          myOpt.systemd-socket-proxyd.${name} = {
            origin = {
              host = innerCfg.services.hermes-agent.backend.host;
              port = innerCfg.services.hermes-agent.backend.port;
              serviceName =
                if innerCfg.services.hermes-agent.backend.mode != "none"
                then "hermes-backend"
                else "hermes-agent";
            };
            proxy.ip-socket = cfg.unix-socket;
          };
          services.hermes-agent = mkMerge [
            {
              inherit (cfg) user group stateDir settings environment environmentFiles;
              enable = true;
              addToSystemPackages = mkDefault true;
              backend = {
                inherit (cfg) host port;
                mode = mkDefault "serve";
              };
            }
            cfg.modules.services.hermes-agent
          ];
          systemd.services = mkMerge [
            {
              hermes-agent.serviceConfig = serviceHardening;
            }
            (mkIf (innerCfg.services.hermes-agent.backend.mode != "none") {
              hermes-backend.serviceConfig = serviceHardening;
            })
          ];
        };
      })
      enabled);
  };
}
