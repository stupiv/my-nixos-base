{
  config,
  lib,
  ...
}:
with lib; let
  enabled = filterAttrs (_: cfg: cfg.enable) config.myOpt.n8n-compose;
  outerCfg = config;

  in-container_home_node_dotn8n = "/home/node/.n8n";
  in-container_home_node_dotn8n-files = "/home/node/.n8n-files";
in {
  options.myOpt.n8n-compose = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({
      name,
      config,
      ...
    }: {
      options = {
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
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        modules.proxy-compose = mkOption {
          type = types.anything;
          default = {};
        };
        caddy.extraConfig = mkOption {
          type = types.lines;
          default = '''';
        };
        n8n = {
          containerName = mkOption {
            type = types.singleLineStr;
            default = "${name}-n8n";
            readOnly = true;
          };
          host = mkOption {
            type = types.singleLineStr;
            default = "127.0.0.1";
          };
          port = mkOption {
            type = types.port;
          };
          image = mkOption {
            type = types.singleLineStr;
            example = "docker.io/n8nio/n8n:2.14.2";
          };
          _home_node_dotn8n = mkOption {
            type = types.singleLineStr;
            example = "/var/lib/test/n8n_v2/n8n_v2/_home_node_.n8n";
          };
          _home_node_dotn8n-files = mkOption {
            type = types.singleLineStr;
            example = "/var/lib/test/n8n_v2/n8n_v2/_home_node_.n8n-files";
          };
          environment = mkOption {
            type = types.anything;
            default = {};
          };
          envFile-key = mkOption {
            type = types.nullOr types.singleLineStr;
            default = null;
          };
        };
      };
    }));
  };

  config = {
    sops.secrets = mapAttrs' (tunnel-id: cfg: (nameValuePair cfg.n8n.envFile-key {})) (filterAttrs (_: cfg: (cfg.n8n.envFile-key != null)) enabled);

    myOpt.proxy-compose =
      mapAttrs' (name: cfg: (nameValuePair name (mkMerge [
        cfg.modules.proxy-compose
        {
          enable = true;
          modules.sleep-on-idle = {
            health-check.path = "/healthz/readiness";
            endpoints.default.origin = {inherit (cfg.n8n) host port;};
            set-cgroup-parent.systemd-services = [];
            set-cgroup-parent.oci-containers = [cfg.n8n.containerName];
            set-cgroup-parent.nixos-containers = [];
          };
          caddy = {
            inherit (cfg.caddy) extraConfig;
          };
        }
      ])))
      enabled;

    systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: [
        "d ${cfg.n8n._home_node_dotn8n} 700 1000 1000 - -"
        "d ${cfg.n8n._home_node_dotn8n-files} 700 1000 1000 - -"
      ])
      enabled);

    virtualisation.oci-containers.containers = mkMerge (mapAttrsToList (
        name: cfg: let
          inherit (config.myOpt.proxy-compose.${cfg.n8n.containerName}) cloudflared;
        in {
          ${cfg.n8n.containerName} = {
            autoStart = false;
            inherit (cfg.n8n) serviceName image;
            environmentFiles = optionals (cfg.n8n.envFile-key != null) [
              config.sops.secrets.${cfg.n8n.envFile-key}.path
            ];
            environment = mkMerge [
              cfg.n8n.environment
              {
                N8N_PROXY_HOPS =
                  if cloudflared.enable
                  then "2"
                  else "1";
                N8N_PROTOCOL = "https";
                N8N_HOST = cfg.proxy-compose.hostname;
                WEBHOOK_URL = "https://${cfg.proxy-compose.hostname}/";
                N8N_PORT = toString cfg.n8n.port;
                NODE_ENV = "production";
                GENERIC_TIMEZONE = config.time.timeZone;
                TZ = config.time.timeZone;
              }
            ];
            volumes = [
              "${cfg.n8n._home_node_dotn8n}:${in-container_home_node_dotn8n}"
              "${cfg.n8n._home_node_dotn8n-files}:${in-container_home_node_dotn8n-files}"
            ];
            ports = ["${cfg.n8n.host}:${toString cfg.n8n.port}:${toString cfg.n8n.port}"];
          };
        }
      )
      enabled);
  };
}
