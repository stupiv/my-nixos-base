{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.camofox;
in {
  options.myOpt.camofox = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        modules.virtualisation.oci-containers.containers = mkOption {
          type = types.anything;
          default = {};
        };
        containerName = mkOption {
          type = types.singleLineStr;
          default = "${name}-camofox";
        };
        serviceName = mkOption {
          type = types.singleLineStr;
          default = outerCfg.virtualisation.oci-containers.containers.${cfg.containerName}.serviceName;
          readOnly = true;
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
          default = "http://${pkgs.myLib.bracketIpv6 "${cfg.host}:${toString cfg.port}"}";
          readOnly = true;
        };
        telemetry = mkOption {
          type = types.bool;
          default = true;
        };
        envfile-key = mkOption {
          type = types.nullOr types.singleLineStr;
          default = "${name}/camofox-envFile";
        };
        sopsFile = mkOption {
          type = types.nullOr types.anything;
          default = null;
        };
        environment = mkOption {
          type = types.attrsOf types.str;
          default = {};
        };
        environmentFiles = mkOption {
          type = types.listOf types.str;
          default = [];
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

    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.containerName} = mkMerge [
          {
            inherit (cfg) image;
            serviceName = mkDefault cfg.containerName;
            autoStart = false;
            environment =
              {
                CAMOFOX_BIND_HOST = cfg.host;
                CAMOFOX_PORT = toString cfg.port;
                CAMOFOX_CRASH_REPORT_ENABLED = boolToString cfg.telemetry;
              }
              // cfg.environment;
            environmentFiles =
              optional (cfg.envfile-key != null) outerCfg.sops.secrets.${cfg.envfile-key}.path
              ++ cfg.environmentFiles;
            extraOptions = [
              "--shm-size=2g"
              "--read-only"
              "--cap-drop=ALL"
              "--security-opt=no-new-privileges"
              "--pids-limit=512"
            ];
          }
          cfg.modules.virtualisation.oci-containers.containers
        ];
      })
      enabled);

    systemd.services = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.serviceName}.serviceConfig = {
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
      })
      enabled);
  };
}
