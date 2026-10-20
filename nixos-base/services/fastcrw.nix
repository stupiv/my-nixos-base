{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.fastcrw;
  tomlFormat = pkgs.formats.toml {};
  yamlFormat = pkgs.formats.yaml {};
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
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "${name}-fastcrw";
        };
        # NOTE: Stock ghcr.io/fastcrw/crw builds `--features cdp,impersonated` without `camoufox`.
        # When camofox.enable = true, supply an image built with:
        #   --build-arg CARGO_PKGS="-p crw-server --features cdp,impersonated,camoufox"
        image = mkOption {
          type = types.singleLineStr;
          default = "ghcr.io/fastcrw/crw:latest";
        };
        host = mkOption {
          type = types.singleLineStr;
          default = "::1";
        };
        port = mkOption {
          type = types.port;
          default = 21023;
        };
        url = mkOption {
          type = types.singleLineStr;
          default = "http://[${cfg.host}]:${toString cfg.port}";
          readOnly = true;
        };
        rendererMode = mkOption {
          type = types.enum [
            "auto"
            "camoufox"
            "lightpanda"
            "playwright"
            "chrome"
            "none"
          ];
          default = "auto";
        };
        camofox = {
          enable = mkOption {
            type = types.bool;
            default = false;
          };
          url = mkOption {
            type = types.nullOr types.singleLineStr;
            default = null;
          };
          includeInAuto = mkOption {
            type = types.bool;
            default = true;
          };
        };
        searxng = {
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
            default = "docker.io/searxng/searxng:2026.5.9-0cba32c15";
          };
          host = mkOption {
            type = types.singleLineStr;
            default = "::1";
          };
          port = mkOption {
            type = types.port;
            default = 8080;
          };
          url = mkOption {
            type = types.singleLineStr;
            default = "http://[${cfg.searxng.host}]:${toString cfg.searxng.port}";
            readOnly = true;
          };
          envFile-key = mkOption {
            type = types.singleLineStr;
            default = "${cfg.secretsDirName}/searxng-envFile";
            readOnly = true;
          };
        };
        settings = mkOption {
          type = types.anything;
          default = {};
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
          default = "${cfg.secretsDirName}/fastcrw-envFile";
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
    assertions =
      mapAttrsToList (name: cfg: {
        assertion = cfg.camofox.enable -> cfg.camofox.url != null;
        message = "myOpt.fastcrw.${name}: camofox.url must be set when camofox.enable = true.";
      })
      enabled;

    sops.secrets = mkMerge (mapAttrsToList (
        _: cfg:
          optionalAttrs (cfg.sopsFile != null) (
            {
              ${cfg.envFile-key} = {inherit (cfg) sopsFile;};
            }
            // optionalAttrs cfg.searxng.enable {
              ${cfg.searxng.envFile-key} = {inherit (cfg) sopsFile;};
            }
          )
      )
      enabled);

    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers = mkMerge (mapAttrsToList (_: cfg: let
      sliceUnit = toSliceUnit cfg.cgroup-parent;
      ns =
        if cfg.networkNamespace != null
        then resolveNetns cfg.networkNamespace
        else null;
      crwConfigFile = tomlFormat.generate "${cfg.serviceName}-config.toml" (recursiveUpdate
        {
          server = {
            inherit (cfg) host port;
            rate_limit_rps = 0;
          };
          renderer =
            {
              mode = cfg.rendererMode;
              camoufox_timeout_ms = 60000;
              camoufox_challenge_wait_ms = 20000;
            }
            // optionalAttrs cfg.camofox.enable {
              camoufox = {
                base_url = cfg.camofox.url;
                include_in_auto = cfg.camofox.includeInAuto;
              };
            };
          search =
            {
              enabled = cfg.searxng.enable;
            }
            // optionalAttrs cfg.searxng.enable {
              search_backend_url = cfg.searxng.url;
            };
          mcp.hide_credits = true;
        }
        cfg.settings);
      searxngSettingsFile = yamlFormat.generate "${cfg.searxng.serviceName}-settings.yml" {
        use_default_settings = true;
        general = {
          instance_name = "crw-search";
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
          bind_address = cfg.searxng.host;
          inherit (cfg.searxng) port;
          limiter = false;
          public_instance = false;
          image_proxy = false;
          method = "GET";
        };
      };
    in
      {
        ${cfg.serviceName} = {
          inherit (cfg) serviceName image;
          autoStart = false;
          networks = optional (ns != null) "ns:${ns.path}";
          volumes =
            [
              "${crwConfigFile}:/etc/crw/config.toml:ro"
            ]
            ++ optional (ns != null) "${ns.resolvConf}:/etc/resolv.conf:ro";
          environment = {
            CRW_CONFIG = "/etc/crw/config.toml";
            CRW_SERVER__HOST = cfg.host;
            CRW_SERVER__PORT = toString cfg.port;
          };
          environmentFiles =
            optional (cfg.sopsFile != null) outerCfg.sops.secrets.${cfg.envFile-key}.path;
          # Stateless hardening: immutable root FS, ephemeral RAM scratch only, zero volumes on host state
          extraOptions =
            [
              "--read-only"
              "--tmpfs=/tmp:rw,noexec,nosuid,size=256m"
              "--cap-drop=ALL"
              "--security-opt=no-new-privileges"
            ]
            ++ optional (sliceUnit != null) "--cgroup-parent=${sliceUnit}";
        };
      }
      // optionalAttrs cfg.searxng.enable {
        ${cfg.searxng.serviceName} = {
          inherit (cfg.searxng) serviceName image;
          autoStart = false;
          networks = optional (ns != null) "ns:${ns.path}";
          volumes =
            [
              "${searxngSettingsFile}:/etc/searxng/settings.yml:ro"
            ]
            ++ optional (ns != null) "${ns.resolvConf}:/etc/resolv.conf:ro";
          environment = {
            SEARXNG_BASE_URL = "${cfg.searxng.url}/";
          };
          environmentFiles =
            optional (cfg.sopsFile != null) outerCfg.sops.secrets.${cfg.searxng.envFile-key}.path;
          extraOptions =
            [
              "--read-only"
              "--tmpfs=/tmp:rw,noexec,nosuid,size=64m"
              "--tmpfs=/var/cache/searxng:rw,noexec,nosuid,size=128m"
              "--cap-drop=ALL"
              "--security-opt=no-new-privileges"
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
    in
      {
        ${cfg.serviceName} = mkMerge [
          (mkIf (ns != null) {
            bindsTo = [ns.unit];
            after = [ns.unit];
          })
          (mkIf cfg.searxng.enable {
            wants = ["${cfg.searxng.serviceName}.service"];
            after = ["${cfg.searxng.serviceName}.service"];
          })
          (mkIf (sliceUnit != null) {
            serviceConfig.Slice = sliceUnit;
          })
        ];
      }
      // optionalAttrs cfg.searxng.enable {
        ${cfg.searxng.serviceName} = mkMerge [
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
