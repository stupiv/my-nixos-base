{
  config,
  lib,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.litellm;
  secretKey = name: "${name}/litellm-envFile";
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
  options.myOpt.litellm = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        containerName = mkOption {
          type = types.singleLineStr;
          default = "${name}-litellm";
        };
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "container@${cfg.containerName}";
          readOnly = true;
        };
        stateDir = mkOption {
          type = types.singleLineStr;
        };
        socketDir = mkOption {
          type = types.singleLineStr;
          default = "/run/sockets/${name}";
        };
        unix-socket = mkOption {
          type = types.singleLineStr;
          default = "${cfg.socketDir}/litellm.sock";
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
        settings = mkOption {
          type = types.anything;
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
        sleep-on-idle = mkOption {
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
    sops.secrets = mkMerge (mapAttrsToList (name: cfg: {
        ${secretKey name} = optionalAttrs (cfg.sopsFile != null) {
          inherit (cfg) sopsFile;
        };
      })
      enabled);

    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (
        _: cfg:
          optionalAttrs (cfg.sleep-on-idle != null) {
            ${cfg.serviceName} = mkMerge [
              cfg.sleep-on-idle
              {
                health-check.path = "/health/liveliness";
                endpoints.default = {
                  origin.ip-socket = cfg.unix-socket;
                  proxy = {inherit (cfg) host port;};
                };
              }
              (optionalAttrs (cfg.cgroup-parent != null) {
                inherit (cfg) cgroup-parent;
              })
            ];
          }
      )
      enabled);

    containers = mkMerge (mapAttrsToList (name: cfg: let
        envPath = outerCfg.sops.secrets.${secretKey name}.path;
        secretsDir = builtins.dirOf envPath;
        ns =
          if cfg.networkNamespace != null
          then resolveNetns cfg.networkNamespace
          else null;
      in {
        ${cfg.containerName} = {
          ephemeral = true;
          privateNetwork = false;
          networkNamespace =
            if ns != null
            then ns.path
            else null;
          autoStart = false;
          bindMounts =
            {
              ${cfg.stateDir} = {
                hostPath = cfg.stateDir;
                isReadOnly = false;
              };
              ${secretsDir} = {
                hostPath = secretsDir;
                isReadOnly = true;
              };
              ${cfg.socketDir} = {
                hostPath = cfg.socketDir;
                isReadOnly = false;
              };
            }
            // optionalAttrs (ns != null) {
              "/etc/resolv.conf" = {
                hostPath = ns.resolvConf;
                isReadOnly = true;
              };
            };
          config = {...}: {
            imports = [
              ../../myLib
              ../systemd-socket-proxyd.nix
            ];
            myOpt.systemd-socket-proxyd.litellm = {
              origin = {inherit (cfg) host port;};
              proxy.ip-socket = cfg.unix-socket;
            };
            services.litellm = {
              inherit (cfg) stateDir host port settings;
              enable = true;
              environmentFile = envPath;
              environment =
                (
                  if cfg.telemetry
                  then {
                    SCARF_NO_ANALYTICS = "False";
                    DO_NOT_TRACK = "False";
                    ANONYMIZED_TELEMETRY = "True";
                  }
                  else {
                    SCARF_NO_ANALYTICS = "True";
                    DO_NOT_TRACK = "True";
                    ANONYMIZED_TELEMETRY = "False";
                  }
                )
                // cfg.environment;
            };
            systemd.services.litellm.serviceConfig = {
              NoNewPrivileges = true;
              PrivateIPC = true;
              ProtectSystem = "strict";
              ReadWritePaths = [cfg.stateDir];
              CapabilityBoundingSet = "";
              AmbientCapabilities = "";
              RestrictSUIDSGID = true;
              RemoveIPC = true;
              SystemCallFilter = [
                "@system-service"
                "~@privileged"
                "~@resources"
              ];
            };
          };
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
            serviceConfig.Slice = mkForce sliceUnit;
          })
        ];
      })
      enabled);

    systemd.tmpfiles.rules = flatten (
      mapAttrsToList (_: cfg: [
        "d '${cfg.stateDir}' 0750 - - - -"
        "d '${cfg.socketDir}' 0750 - - - -"
      ])
      enabled
    );
  };
}
