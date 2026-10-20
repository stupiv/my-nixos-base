{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.qdrant;
  settingsFormat = pkgs.formats.yaml {};
  secretKey = name: "${name}/qdrant-envFile";
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
  options.myOpt.qdrant = mkOption {
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
        package = mkPackageOption pkgs "qdrant" {};
        webUIPackage = mkPackageOption pkgs "qdrant-web-ui" {};
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "${name}-qdrant";
        };
        user = mkOption {
          type = types.singleLineStr;
          default = "qdrant-${name}";
        };
        group = mkOption {
          type = types.singleLineStr;
          default = "qdrant-${name}";
        };
        stateDir = mkOption {
          type = types.singleLineStr;
        };
        host = mkOption {
          type = types.singleLineStr;
          default = "::1";
        };
        httpPort = mkOption {
          type = types.port;
        };
        grpcPort = mkOption {
          type = types.port;
        };
        httpUrl = mkOption {
          type = types.singleLineStr;
          default = mkHttpUrl cfg.host cfg.httpPort;
        };
        grpcUrl = mkOption {
          type = types.singleLineStr;
          default = mkHttpUrl cfg.host cfg.grpcPort;
        };
        telemetry = mkOption {
          type = types.bool;
          default = true;
        };
        settings = mkOption {
          type = settingsFormat.type;
          default = {};
        };
        environment = mkOption {
          type = types.attrsOf types.str;
          default = {};
        };
        sopsFile = mkOption {
          type = types.nullOr types.anything;
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
    users.groups = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.group} = {};
      })
      enabled);

    users.users = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.user} = {
          isSystemUser = true;
          inherit (cfg) group;
          home = cfg.stateDir;
        };
      })
      enabled);

    sops.secrets = mkMerge (mapAttrsToList (name: cfg: {
        ${secretKey name} = optionalAttrs (cfg.sopsFile != null) {
          inherit (cfg) sopsFile;
        };
      })
      enabled);

    systemd.services = mkMerge (mapAttrsToList (name: cfg: let
        sliceUnit = toSliceUnit cfg.cgroup-parent;
        ns =
          if cfg.networkNamespace != null
          then resolveNetns cfg.networkNamespace
          else null;
        configFile = settingsFormat.generate "${cfg.serviceName}-config.yaml" (recursiveUpdate
          {
            storage = {
              storage_path = "${cfg.stateDir}/storage";
              snapshots_path = "${cfg.stateDir}/snapshots";
              on_disk_payload = true;
            };
            service = {
              host = cfg.host;
              http_port = cfg.httpPort;
              grpc_port = cfg.grpcPort;
              static_content_dir = cfg.webUIPackage;
              enable_cors = true;
            };
            cluster.enabled = false;
            telemetry_disabled = !cfg.telemetry;
          }
          cfg.settings);
      in {
        ${cfg.serviceName} = mkMerge [
          {
            description = "Qdrant vector search engine (${name})";
            wantedBy = optional cfg.autoStart "multi-user.target";
            inherit (cfg) environment;
            serviceConfig =
              {
                User = cfg.user;
                Group = cfg.group;
                WorkingDirectory = cfg.stateDir;
                LimitNOFILE = 65536;
                ExecStart = "${cfg.package}/bin/qdrant --config-path ${configFile}";
                EnvironmentFile = outerCfg.sops.secrets.${secretKey name}.path;
                Restart = "on-failure";
                ReadWritePaths = [cfg.stateDir];
                NoNewPrivileges = true;
                PrivateTmp = true;
                PrivateDevices = true;
                PrivateIPC = true;
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

    systemd.tmpfiles.rules =
      mapAttrsToList (
        _: cfg: "d '${cfg.stateDir}' 0750 ${cfg.user} ${cfg.group} - -"
      )
      enabled;
  };
}
