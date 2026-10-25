# n8n on native services.n8n instead of the oci-container in n8n-compose.nix.
#
# - [ ] Migration: services.n8n pins N8N_USER_FOLDER to /var/lib/n8n (read-only
#       option, managed by StateDirectory=n8n + DynamicUser), so the old
#       container paths (_home_node_dotn8n, _home_node_dotn8n-files) are gone.
#       Copy the old state before enabling:
#         install -d -m 0700 /var/lib/n8n/.n8n
#         rsync -a --delete <old _home_node_dotn8n>/ /var/lib/n8n/.n8n/
# - [ ] The old module pinned the image (e.g. docker.io/n8nio/n8n:2.14.2), while
#       services.n8n uses pkgs.n8n from the flake's nixpkgs. Check the version
#       before switching back and forth, n8n migrates its sqlite DB on start.
# - [ ] Do not enable this together with myOpt.n8n-compose (v1): both bind the
#       same port and would fight over the same state.
# - [ ] environment variables NODES_EXCLUDE=[] N8N_NODES_INCLUDE
#       N8N_ENABLE_EXECUTE_COMMAND ??
{
  config,
  lib,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.n8n-compose-v2;
  names = attrNames enabled;
  toSliceUnit = p:
    if p == null
    then null
    else if hasSuffix ".slice" p
    then p
    else "${p}.slice";
in {
  options.myOpt.n8n-compose-v2 = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        # services.n8n is a singleton module, so the unit name is fixed and the
        # option is kept read-only for consumers (proxy-compose,
        # sleep-on-idle) that key off a service name.
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "n8n";
          readOnly = true;
        };
        localMode = {
          enable = mkOption {
            type = types.bool;
            default = false;
          };
          port = mkOption {
            type = types.port;
            default = 11761;
          };
        };
        host = mkOption {
          type = types.singleLineStr;
          default = "127.0.0.1";
        };
        port = mkOption {
          type = types.port;
          default = 5678;
        };
        telemetry = mkOption {
          type = types.bool;
          default = false;
        };
        # Name of the sops secret whose content is passed as EnvironmentFile.
        envFile-key = mkOption {
          type = types.nullOr types.singleLineStr;
          default = null;
        };
        environment = mkOption {
          type = types.attrsOf types.str;
          default = {};
        };
        cgroup-parent = mkOption {
          type = types.nullOr types.singleLineStr;
          default = null;
        };
        proxy-compose = mkOption {
          type = types.anything;
          default = {};
        };
        caddy.extraConfig = mkOption {
          type = types.lines;
          default = '''';
        };
      };
    }));
  };

  config = mkIf (names != []) (let
    name = head names;
    cfg = enabled.${name};
    sliceUnit = toSliceUnit cfg.cgroup-parent;
    inherit (outerCfg.myOpt.proxy-compose.${cfg.serviceName}) cloudflared;
  in {
    assertions = [
      {
        assertion = length names == 1;
        message = "myOpt.n8n-compose-v2: services.n8n is a singleton, enable at most one instance (enabled: ${concatStringsSep ", " names})";
      }
      {
        assertion = filterAttrs (_: v1: v1.enable) (outerCfg.myOpt.n8n-compose or {}) == {};
        message = "myOpt.n8n-compose (v1, oci-container) and myOpt.n8n-compose-v2 (native services.n8n) must not be enabled at the same time";
      }
    ];

    # Only declares the secret; the sops file stays with the caller
    # (sops.secrets.<key>.sopsFile or sops.defaultSopsFile).
    sops.secrets =
      optionalAttrs (cfg.envFile-key != null) {
        ${cfg.envFile-key} = {};
      };

    myOpt.proxy-compose =
      mapAttrs' (_: cfg: (nameValuePair cfg.serviceName (mkMerge [
        cfg.proxy-compose
        {
          localMode = {
            inherit (cfg.localMode) enable;
            port = mkDefault cfg.localMode.port;
          };
          sleep-on-idle = {
            health-check.path = "/healthz/readiness";
            endpoints.default.origin = {
              inherit (cfg) host port;
            };
          };
          caddy = {
            inherit (cfg.caddy) extraConfig;
          };
        }
      ])))
      enabled;

    services.n8n = {
      enable = true;
      environment =
        {
          N8N_PORT = toString cfg.port;
          N8N_LISTEN_ADDRESS = cfg.host;
          N8N_PROXY_HOPS =
            if cloudflared.enable
            then "2"
            else "1";
          N8N_PROTOCOL = "https";
          N8N_HOST = cfg.proxy-compose.hostName;
          WEBHOOK_URL = "https://${cfg.proxy-compose.hostName}/";
          N8N_DIAGNOSTICS_ENABLED = boolToString cfg.telemetry;
          GENERIC_TIMEZONE = outerCfg.time.timeZone;
          TZ = outerCfg.time.timeZone;
        }
        // cfg.environment;
    };

    systemd.services.n8n.serviceConfig =
      optionalAttrs (cfg.envFile-key != null) {
        EnvironmentFile = outerCfg.sops.secrets.${cfg.envFile-key}.path;
      }
      // optionalAttrs (sliceUnit != null) {
        Slice = sliceUnit;
      };
  });
}
