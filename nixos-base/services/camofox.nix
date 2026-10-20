{
  config,
  lib,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.camofox-compose;
  secretKey = name: "${name}/camofox-envFile";
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
  options.myOpt.camofox-compose = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "${name}-camofox";
        };
        image = mkOption {
          type = types.singleLineStr;
          example = "ghcr.io/jo-inc/camofox-browser:1.18.1";
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
        telemetry = mkOption {
          type = types.bool;
          default = true;
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
        environment = mkOption {
          type = types.attrsOf types.str;
          default = {};
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

    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers = mkMerge (mapAttrsToList (name: cfg: let
        sliceUnit = toSliceUnit cfg.cgroup-parent;
        ns =
          if cfg.networkNamespace != null
          then resolveNetns cfg.networkNamespace
          else null;
      in {
        ${cfg.serviceName} = {
          inherit (cfg) serviceName image;
          autoStart = false;
          networks = optional (ns != null) "ns:${ns.path}";
          volumes = optional (ns != null) "${ns.resolvConf}:/etc/resolv.conf:ro";
          environment =
            {
              CAMOFOX_BIND_HOST = cfg.host;
              CAMOFOX_PORT = toString cfg.port;
              CAMOFOX_CRASH_REPORT_ENABLED = boolToString cfg.telemetry;
            }
            // cfg.environment;
          environmentFiles = [outerCfg.sops.secrets.${secretKey name}.path];
          extraOptions =
            [
              "--shm-size=2g" # Firefox needs real shared memory; the default 64MB is not enough
              "--read-only"
              "--tmpfs=/tmp:rw,nosuid,nodev,size=512m"
              "--tmpfs=/run:rw,noexec,nosuid,nodev,size=32m"
              "--tmpfs=/root/.camofox:rw,noexec,nosuid,nodev,size=256m"
              "--cap-drop=ALL"
              "--security-opt=no-new-privileges"
              "--pids-limit=512"
            ]
            ++ optional (sliceUnit != null) "--cgroup-parent=${sliceUnit}";
        };
      })
      enabled);

    systemd.services = mkMerge (mapAttrsToList (_: cfg: let
        sliceUnit = toSliceUnit cfg.cgroup-parent;
        ns =
          if cfg.networkNamespace != null
          then resolveNetns cfg.networkNamespace
          else null;
      in {
        ${cfg.serviceName} = mkMerge [
          {
            serviceConfig = {
              ProtectHome = true;
              ProtectClock = true;
              ProtectHostname = true;
              ProtectKernelLogs = true;
              ProtectKernelModules = true;
              ProtectKernelTunables = true;
              LockPersonality = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
            };
          }
          (mkIf (ns != null) {
            bindsTo = [ns.unit];
            after = [ns.unit];
          })
          (mkIf (sliceUnit != null) {
            serviceConfig.Slice = sliceUnit;
          })
        ];
      })
      enabled);
  };
}
