{
  config,
  lib,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (name: cfg: cfg.enable) outerCfg.myOpt.n8n-oci-compose;
  in-container_home_node_dotn8n = "/home/node/.n8n";
  in-container_home_node_dotn8n-files = "/home/node/.n8n-files";
in {
  options.myOpt.n8n-oci-compose = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        modules = {
          proxy-compose = mkOption {
            type = types.anything;
          };
          virtualisation.oci-containers.containers = mkOption {
            type = types.anything;
          };
        };
        oci-container.name = mkOption {
          type = types.singleLineStr;
          default = "n8n-oci-compose-${name}";
        };
        host = mkOption {
          type = types.singleLineStr;
          default = "::1";
        };
        port = mkOption {
          type = types.port;
        };
        _home_node_dotn8n = mkOption {
          type = types.singleLineStr;
        };
        _home_node_dotn8n-files = mkOption {
          type = types.singleLineStr;
        };
        sops.dotenv = {
          key = mkOption {
            type = types.singleLineStr;
          };
          sopsFile = mkOption {
            type = types.path;
          };
        };
      };
    }));
  };

  config = {
    sops.secrets = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.sops.dotenv.key} = {inherit (cfg.sops.dotenv) sopsFile;};
      })
      enabled);

    myOpt.proxy-compose = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.oci-container.name} = mkMerge [
          cfg.modules.proxy-compose
          {
            enable = true;
            modules.sleep-on-idle = {
              health-check.path = "/healthz/readiness";
              endpoints.default.origin = {inherit (cfg) host port;};
              set-cgroup-parent.systemd-services = [];
              set-cgroup-parent.oci-containers = [cfg.oci-container.name];
              set-cgroup-parent.nixos-containers = [];
            };
          }
        ];
      })
      enabled);

    systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: [
        "d ${cfg._home_node_dotn8n} 711 1000 1000 - -"
        "d ${cfg._home_node_dotn8n-files} 711 1000 1000 - -"
      ])
      enabled);

    virtualisation.oci-containers.containers = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.oci-container.name} = {
          inherit (cfg.modules.virtualisation.oci-containers.containers) image;
          autoStart = false;
          environmentFiles = [
            outerCfg.sops.secrets.${cfg.sops.dotenv.key}.path
          ];
          environment = {
            N8N_PROXY_HOPS =
              if cfg.modules.proxy-compose ? cloudflared
              then "2"
              else "1";
            N8N_PROTOCOL = "https";
            N8N_HOST = cfg.proxy-compose.hostname;
            WEBHOOK_URL = "https://${cfg.proxy-compose.hostname}/";
            N8N_PORT = toString cfg.port;
            NODE_ENV = "production";
            GENERIC_TIMEZONE = outerCfg.time.timeZone;
            TZ = outerCfg.time.timeZone;
          };
          volumes = [
            "${cfg._home_node_dotn8n}:${in-container_home_node_dotn8n}"
            "${cfg._home_node_dotn8n-files}:${in-container_home_node_dotn8n-files}"
          ];
          ports = ["${cfg.host}:${toString cfg.port}:${toString cfg.port}"];
        };
      })
      enabled);
  };
}
