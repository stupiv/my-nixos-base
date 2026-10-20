{
  config,
  lib,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.camofox-compose;
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
          default = 11982;
        };
        url = mkOption {
          type = types.singleLineStr;
          default = "http://[${cfg.host}]:${toString cfg.port}";
          readOnly = true;
        };
        sopsFile = mkOption {
          type = types.nullOr types.anything;
          default = null;
        };
        secretsDirName = mkOption {
          type = types.singleLineStr;
          default = name;
        };
        envFile-key = mkOption {
          type = types.singleLineStr;
          default = "${cfg.secretsDirName}/camofox-envFile";
          readOnly = true;
        };
        cgroup-parent = mkOption {
          type = types.nullOr types.singleLineStr;
          default = null;
        };
        networkNamespace = mkOption {
          type = types.nullOr types.singleLineStr;
          default = null;
        };
        extraEnvironment = mkOption {
          type = types.attrsOf types.str;
          default = {};
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    sops.secrets = mkMerge (mapAttrsToList (
        _: cfg:
          optionalAttrs (cfg.sopsFile != null) {
            ${cfg.envFile-key} = {inherit (cfg) sopsFile;};
          }
      )
      enabled);

    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers = mkMerge (mapAttrsToList (_: cfg: let
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
              CAMOFOX_CRASH_REPORT_ENABLED = "false";
            }
            // cfg.extraEnvironment;
          environmentFiles =
            optional (cfg.sopsFile != null) outerCfg.sops.secrets.${cfg.envFile-key}.path;
          extraOptions =
            [
              "--shm-size=2g" # Firefox needs real shared memory; the default 64MB is not enough
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
