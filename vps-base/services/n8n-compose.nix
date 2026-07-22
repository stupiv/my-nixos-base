# TODO 2605
## use services.n8n. ??
## enviroment variables NODES_EXCLUDE=[] N8N_NODES_INCLUDE N8N_ENABLE_EXECUTE_COMMAND ??
{
  config,
  lib,
  ...
}:
with lib; let
  enabled-n8n-compose = filterAttrs (_: cfg: cfg.enable) config.myOpt.n8n-compose;
  autoStart = false;
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
        proxy-compose = mkOption {
          type = types.anything;
          default = {};
        };
        caddy.extraConfig = mkOption {
          type = types.lines;
          default = '''';
        };
        n8n = {
          serviceName = mkOption {
            type = types.singleLineStr;
            default = "${name}-n8n";
            readOnly = true;
          };
          listen-address = mkOption {
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
          envfile-key = mkOption {
            type = types.nullOr types.singleLineStr;
            default = null;
          };
        };
        default-caddy-origin-socket-address = mkOption {
          type = types.singleLineStr;
          default = outerCfg.myOpt.proxy-compose.${config.n8n.serviceName}.default-caddy-origin-socket-address;
          readOnly = true;
        };
      };
    }));
  };

  config = {
    sops.secrets = mapAttrs' (tunnel_id: cfg: (nameValuePair cfg.n8n.envfile-key {})) (filterAttrs (_: cfg: (cfg.n8n.envfile-key != null)) enabled-n8n-compose);

    myOpt.proxy-compose =
      mapAttrs' (name: cfg: (nameValuePair cfg.n8n.serviceName (mkMerge [
        cfg.proxy-compose
        {
          localMode.port = mkDefault 11761;
          sleep-on-idle = {
            health-check.path = "/healthz/readiness";
            endpoints.default.origin = {
              inherit (cfg.n8n) listen-address port;
            };
          };
          caddy = {
            inherit (cfg.caddy) extraConfig;
          };
        }
      ])))
      enabled-n8n-compose;

    systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: [
        "d ${cfg.n8n._home_node_dotn8n} 700 1000 1000 - -"
        "d ${cfg.n8n._home_node_dotn8n-files} 700 1000 1000 - -"
      ])
      enabled-n8n-compose);

    virtualisation.oci-containers.containers = mkMerge (mapAttrsToList (
        name: cfg: let
          inherit (config.myOpt.proxy-compose.${cfg.n8n.serviceName}) cloudflared;
        in {
          ${cfg.n8n.serviceName} = {
            inherit autoStart;
            inherit (cfg.n8n) serviceName image;
            environmentFiles = optionals (cfg.n8n.envfile-key != null) [
              config.sops.secrets.${cfg.n8n.envfile-key}.path
            ];
            environment = mkMerge [
              cfg.n8n.environment
              {
                N8N_PROXY_HOPS =
                  if cloudflared.enable
                  then "2"
                  else "1";
                N8N_PROTOCOL = "https";
                N8N_HOST = cfg.proxy-compose.hostName;
                WEBHOOK_URL = "https://${cfg.proxy-compose.hostName}/";
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
            ports = ["${cfg.n8n.listen-address}:${toString cfg.n8n.port}:${toString cfg.n8n.port}"];
          };
        }
      )
      enabled-n8n-compose);
  };
}
