{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.searxng-compose;
  yamlFormat = pkgs.formats.yaml {};
  secretKey = name: "${name}/searxng-envFile";
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
  options.myOpt.searxng-compose = mkOption {
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
          default = "${name}-searxng";
        };
        image = mkOption {
          type = types.singleLineStr;
          example = "docker.io/searxng/searxng:2026.5.9-0cba32c15";
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
        settings = mkOption {
          type = types.anything;
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
        settingsFile = yamlFormat.generate "${cfg.serviceName}-settings.yml" (recursiveUpdate
          {
            use_default_settings = true;
            general = {
              instance_name = "searxng";
              privacypolicy_url = false;
              contact_url = false;
              donation_url = false;
            };
            search = {
              safe_search = 0;
              autocomplete = "";
              default_lang = "auto";
              formats = [
                "html"
                "json"
              ];
            };
            server = {
              bind_address = cfg.host;
              inherit (cfg) port;
              limiter = false;
              public_instance = false;
              image_proxy = false;
              method = "GET";
            };
          }
          cfg.settings);
      in {
        ${cfg.serviceName} = {
          inherit (cfg) serviceName image;
          autoStart = false;
          networks = optional (ns != null) "ns:${ns.path}";
          volumes =
            [
              "${settingsFile}:/etc/searxng/settings.yml:ro"
            ]
            ++ optional (ns != null) "${ns.resolvConf}:/etc/resolv.conf:ro";
          environment =
            {
              GRANIAN_HOST = cfg.host;
              GRANIAN_PORT = toString cfg.port;
              SEARXNG_PORT = toString cfg.port;
              SEARXNG_BASE_URL = "${cfg.url}/";
            }
            // cfg.environment;
          environmentFiles = [outerCfg.sops.secrets.${secretKey name}.path];
          extraOptions =
            [
              "--user=977:977"
              "--read-only"
              "--tmpfs=/tmp:rw,noexec,nosuid,nodev,size=64m"
              "--tmpfs=/run:rw,noexec,nosuid,nodev,size=16m"
              "--tmpfs=/var/cache/searxng:rw,noexec,nosuid,nodev,size=128m,uid=977,gid=977"
              "--cap-drop=ALL"
              "--security-opt=no-new-privileges"
              "--pids-limit=256"
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
