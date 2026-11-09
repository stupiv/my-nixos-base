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
        modules = {
          systemd.services = mkOption {
            type = types.submodule ({...}: {
              freeformType = types.anything;
              options = {
                environment = mkOption {
                  freeformType = types.anything;
                  type = types.submodule ({...}: {
                    options = {
                      CRW_SERVER__HOST = mkOption {
                        type = types.anything;
                      };
                      CRW_SERVER__PORT = mkOption {
                        type = types.anything;
                      };
                    };
                  });
                };
              };
            });
          };
        };
        netns-id = mkOption {
          type = types.singleLineStr;
        };
        sleep-on-idle-id = mkOption {
          type = types.singleLineStr;
        };
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "fastcrw@${name}";
          readOnly = true;
        };
        package = mkOption {
          type = types.package;
        };
        sops.envfile = {
          cfg = mkOption {
            type = types.anything;
            default = outerCfg.sops.secrets.${cfg.sops.envfile.key};
            readOnly = true;
          };
          key = mkOption {
            type = types.anything;
          };
          sopsFile = mkOption {
            type = types.anything;
          };
        };
      };
    }));
  };
  config = mkIf (enabled != {}) {
    sops.secrets = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.sops.envfile.key} = {
          inherit (cfg.sops.envfile) sopsFile;
        };
      })
      enabled);

    systemd.services = mkMerge (
      [
        {
          "fastcrw@" = {
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
          cfg.modules.systemd.services
          {
            overrideStrategy = "asDropin";
            restartTriggers = [cfg.package];
            serviceConfig = {
              ExecStart = "${cfg.package}/bin/crw-server";
              EnvironmentFile = [
                cfg.sops.envfile.cfg.path
              ];
            };
          }
        ];
      })
      enabled
    );

    myOpt.netns = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.netns-id}.set-network-namespace = {
          systemd-services = [
            cfg.serviceName
          ];
        };
      })
      enabled);

    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.sleep-on-idle-id}.set-cgroup-parent = {
          systemd-services = [
            cfg.serviceName
          ];
        };
      })
      enabled);
  };
}
