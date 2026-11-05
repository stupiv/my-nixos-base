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
        modules.services.keycloak = mkOption {
          type = types.anything;
          default = {};
        };
        container = mkOption {
          type = types.anything;
          default = {};
        };
        unix-socket = mkOption {
          type = types.singleLineStr;
          default = "${cfg.container.shared-run-dir}/keycloak.sock";
          readOnly = true;
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    containers = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.container.name}.config = {config, ...} @ innerArgs: let
          innerCfg = innerArgs.config;
        in {
          imports = [
            ./systemd-socket-proxyd.nix
          ];
          myOpt.systemd-socket-proxyd.${name} = {
            origin = {
              host = innerCfg.services.keycloak.settings.http-host;
              port = innerCfg.services.keycloak.settings.http-port;
              serviceName = "keycloak";
            };
            proxy.ip-socket = cfg.unix-socket;
          };
          services.keycloak = mkMerge [
            cfg.modules.services.keycloak
            {
              enable = true;
              package = mkDefault cfg.modules.services.keycloak.package;
              database = {
                inherit (cfg.modules.services.keycloak.database) type host createLocally;
              };
              settings = {
                inherit (cfg.modules.services.keycloak.settings) hostname;
                http-host = mkDefault "::1";
                http-port = mkDefault 25546;
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
      })
      enabled);
  };
}
