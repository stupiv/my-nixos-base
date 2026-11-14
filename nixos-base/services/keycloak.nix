{
  config,
  lib,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.keycloak;
in {
  options.myOpt.keycloak = mkOption {
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
          services.keycloak = mkOption {
            type = types.anything;
          };
        };
        container.name = mkOption {
          type = types.singleLineStr;
        };
        sleep-on-idle-id = mkOption {
          type = types.nullOr types.singleLineStr;
        };
        netns-id = mkOption {
          type = types.nullOr types.singleLineStr;
        };
        host = mkOption {
          type = types.singleLineStr;
          default = "::1";
        };
        port = mkOption {
          type = types.port;
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    containers = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.container.name} = {
          config = {config, ...} @ innerArgs: let
            innerCfg = innerArgs.config;
          in {
            services.keycloak = mkMerge [
              cfg.modules.services.keycloak
              {
                enable = true;
                package = mkDefault cfg.modules.services.keycloak.package;
                plugins = optionals (hasPrefix "/" cfg.modules.services.keycloak.database.host) (with cfg.modules.services.keycloak.package.plugins; [
                  junixsocket-common
                  junixsocket-native-common
                ]);
                database = {
                  inherit (cfg.modules.services.keycloak.database) type host createLocally;
                };
                settings = {
                  inherit (cfg.modules.services.keycloak.settings) hostname;
                  # inherit (cfg.modules.services.keycloak.settings) hostname http-port;
                  # http-host = mkDefault "::1";
                  http-host = cfg.host;
                  http-port = cfg.port;
                  http-enabled = mkDefault true;
                  proxy-headers = mkDefault "xforwarded";
                };
              }
            ];
            systemd.services.keycloak.serviceConfig = {
              NoNewPrivileges = true;
              PrivateTmp = true;
              PrivateDevices = true;
              PrivateIPC = true;
              PrivateMounts = true;
              ProtectSystem = "strict";
              ProtectHome = true;
              ProtectClock = true;
              ProtectControlGroups = true;
              ProtectHostname = true;
              ProtectKernelLogs = true;
              ProtectKernelModules = true;
              ProtectKernelTunables = true;
              ProtectProc = "invisible";
              DevicePolicy = "closed";
              DeviceAllow = "";
              CapabilityBoundingSet = ["CAP_NET_BIND_SERVICE"];
              KeyringMode = "private";
              LimitCORE = 0;
              LockPersonality = true;
              RemoveIPC = true;
              RestrictAddressFamilies = [
                "AF_INET"
                "AF_INET6"
                "AF_UNIX"
                "AF_NETLINK"
              ];
              RestrictNamespaces = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              SystemCallArchitectures = "native";
              SystemCallFilter = [
                "@system-service"
                "mincore"
                "~@privileged"
              ];
              SystemCallErrorNumber = "EPERM";
              UMask = "0077";
            };
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
