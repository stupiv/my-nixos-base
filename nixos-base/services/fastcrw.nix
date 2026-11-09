{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.fastcrw;
in {
  options.myOpt.fastcrw = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        autoStart = mkOption {
          type = types.bool;
          default = false;
        };
        package = mkOption {
          type = types.package;
        };
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "fastcrw@${name}";
          readOnly = true;
        };
        host = mkOption {
          type = types.singleLineStr;
          default = "::1";
        };
        port = mkOption {
          type = types.port;
        };
        url = mkOption {
          type = types.singleLineStr;
          default = "http://${pkgs.myLib.bracketIpv6 "${cfg.host}:${toString cfg.port}"}";
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
        envfile-key = mkOption {
          type = types.nullOr types.singleLineStr;
          default = "${name}/fastcrw-envFile";
        };
        sopsFile = mkOption {
          type = types.nullOr types.anything;
          default = null;
        };
        modules.systemd.services = mkOption {
          type = types.anything;
          default = {};
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    sops.secrets = mkMerge (mapAttrsToList (_: cfg:
        optionalAttrs (cfg.envfile-key != null) {
          ${cfg.envfile-key} = optionalAttrs (cfg.sopsFile != null) {
            inherit (cfg) sopsFile;
          };
        })
      enabled);

    systemd.services = mkMerge (
      [
        {
          "fastcrw@" = {
            description = "Stateless FastCRW web scraper and search API (%i)";
            serviceConfig = {
              Restart = "on-failure";
              DynamicUser = true;
              User = "fastcrw-%i";
              Group = "fastcrw-%i";
              NoNewPrivileges = true;
              PrivateTmp = true;
              PrivateDevices = true;
              PrivateIPC = true;
              PrivateUsers = true;
              ProtectSystem = "strict";
              ProtectHome = true;
              ProtectClock = true;
              ProtectControlGroups = true;
              ProtectHostname = true;
              ProtectKernelLogs = true;
              ProtectKernelModules = true;
              ProtectKernelTunables = true;
              ProtectProc = "invisible";
              ProcSubset = "pid";
              DevicePolicy = "closed";
              CapabilityBoundingSet = "";
              AmbientCapabilities = "";
              KeyringMode = "private";
              LimitCORE = 0;
              LockPersonality = true;
              MemoryDenyWriteExecute = true;
              RemoveIPC = true;
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
                "~@resources"
              ];
              UMask = "0077";
            };
          };
        }
      ]
      ++ mapAttrsToList (_: cfg: {
        ${cfg.serviceName} = mkMerge [
          {
            overrideStrategy = "asDropin";
            restartTriggers = [cfg.package];
            wantedBy = optional cfg.autoStart "multi-user.target";
            environment =
              {
                CRW_SERVER__HOST = cfg.host;
                CRW_SERVER__PORT = toString cfg.port;
              }
              // cfg.environment;
            serviceConfig = {
              ExecStart = "${cfg.package}/bin/crw-server";
              EnvironmentFile =
                optional (cfg.envfile-key != null) outerCfg.sops.secrets.${cfg.envfile-key}.path
                ++ cfg.environmentFiles;
            };
          }
          cfg.modules.systemd.services
        ];
      })
      enabled
    );
  };
}
