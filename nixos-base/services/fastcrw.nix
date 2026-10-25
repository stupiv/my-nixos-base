{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.fastcrw;
  mkHttpUrl = host: port: let
    bracketedHost =
      if hasPrefix "[" host
      then host
      else if hasInfix ":" host
      then "[${host}]"
      else host;
  in "http://${bracketedHost}:${toString port}";
  toSliceUnit = p:
    if p == null
    then null
    else if hasSuffix ".slice" p
    then p
    else "${p}.slice";
  resolveNetns = nsName: let
    entry = outerCfg.myOpt.netns.${nsName} or null;
  in
    if entry != null
    then {
      inherit (entry) path resolvConf unit;
    }
    else {
      path = "/run/netns/${nsName}";
      resolvConf = "/etc/netns/${nsName}/resolv.conf";
      unit = "${nsName}.service";
    };
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
        package = mkPackageOption pkgs "fastcrw" {};
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "${name}-fastcrw";
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
          default = mkHttpUrl cfg.host cfg.port;
        };
        environment = mkOption {
          type = types.attrsOf types.str;
          default = {};
        };
        # Name of the sops secret whose content is passed as EnvironmentFile.
        envFile-key = mkOption {
          type = types.nullOr types.singleLineStr;
          default = null;
        };
        cgroup-parent = mkOption {
          type = types.nullOr types.singleLineStr;
          default = null;
        };
        networkNamespace = mkOption {
          type = types.nullOr types.singleLineStr;
          default = null;
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    # Only declares the secret; the sops file stays with the caller
    # (sops.secrets.<key>.sopsFile or sops.defaultSopsFile).
    sops.secrets = mkMerge (mapAttrsToList (_: cfg:
        optionalAttrs (cfg.envFile-key != null) {
          ${cfg.envFile-key} = {};
        })
      enabled);

    systemd.services = mkMerge (mapAttrsToList (name: cfg: let
        sliceUnit = toSliceUnit cfg.cgroup-parent;
        ns =
          if cfg.networkNamespace != null
          then resolveNetns cfg.networkNamespace
          else null;
      in {
        ${cfg.serviceName} = mkMerge [
          {
            description = "Stateless FastCRW web scraper and search API (${name})";
            wantedBy = optional cfg.autoStart "multi-user.target";
            environment =
              {
                CRW_SERVER__HOST = cfg.host;
                CRW_SERVER__PORT = toString cfg.port;
              }
              // cfg.environment;
            serviceConfig =
              {
                ExecStart = "${cfg.package}/bin/crw-server";
                Restart = "on-failure";
                DynamicUser = true;
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
              }
              // optionalAttrs (cfg.envFile-key != null) {
                EnvironmentFile = outerCfg.sops.secrets.${cfg.envFile-key}.path;
              }
              // optionalAttrs (ns != null) {
                NetworkNamespacePath = ns.path;
                BindReadOnlyPaths = ["${ns.resolvConf}:/etc/resolv.conf"];
              }
              // optionalAttrs (sliceUnit != null) {
                Slice = sliceUnit;
              };
          }
          (mkIf (ns != null) {
            bindsTo = [ns.unit];
            after = [ns.unit];
          })
        ];
      })
      enabled);
  };
}
