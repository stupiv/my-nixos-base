{
  config,
  lib,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.qdrant;
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
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "${name}-qdrant";
        };
        image = mkOption {
          type = types.singleLineStr;
          default = "docker.io/qdrant/qdrant:latest";
          example = "docker.io/qdrant/qdrant:v1.17.0";
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
          default = 6333;
        };
        grpcPort = mkOption {
          type = types.port;
          default = 6334;
        };
        httpUrl = mkOption {
          type = types.singleLineStr;
          default = "http://[${cfg.host}]:${toString cfg.httpPort}";
          readOnly = true;
        };
        grpcUrl = mkOption {
          type = types.singleLineStr;
          default = "http://[${cfg.host}]:${toString cfg.grpcPort}";
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
          default = "${cfg.secretsDirName}/qdrant-envFile";
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
          volumes =
            [
              "${cfg.stateDir}:/qdrant/storage"
            ]
            ++ optional (ns != null) "${ns.resolvConf}:/etc/resolv.conf:ro";
          environment = {
            QDRANT__SERVICE__HOST = cfg.host;
            QDRANT__SERVICE__HTTP_PORT = toString cfg.httpPort;
            QDRANT__SERVICE__GRPC_PORT = toString cfg.grpcPort;
            QDRANT__TELEMETRY_DISABLED = "true";
          };
          environmentFiles =
            optional (cfg.sopsFile != null) outerCfg.sops.secrets.${cfg.envFile-key}.path;
          extraOptions = optional (sliceUnit != null) "--cgroup-parent=${sliceUnit}";
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

    systemd.tmpfiles.rules = mapAttrsToList (_: cfg: "d '${cfg.stateDir}' - - - - -") enabled;
  };
}
