{
  config,
  lib,
  pkgs,
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
          default = "127.0.0.1";
          readOnly = true;
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
        sops.envFile = {
          key = mkOption {
            type = types.singleLineStr;
          };
          sopsFile = mkOption {
            type = types.path;
          };
        };
        proxy-compose-id = mkOption {
          type = types.singleLineStr;
          default = name;
        };
        sleep-on-idle-id = mkOption {
          type = types.singleLineStr;
          default = name;
        };
        proxy-compose-cfg = mkOption {
          type = types.anything;
          default = outerCfg.myOpt.proxy-compose.${cfg.proxy-compose-id};
          readOnly = true;
        };
        sleep-on-idle-cfg = mkOption {
          type = types.anything;
          default = outerCfg.myOpt.sleep-on-idle.${cfg.sleep-on-idle-id};
          readOnly = true;
        };
      };
    }));
  };

  config = {
    sops.secrets = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.sops.envFile.key} = {inherit (cfg.sops.envFile) sopsFile;};
      })
      enabled);

    myOpt.proxy-compose = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.proxy-compose-id} = mkMerge [
          cfg.modules.proxy-compose
          {
            enable = true;
            inherit (cfg) sleep-on-idle-id;
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
        "d '${cfg._home_node_dotn8n}' 0711 1000 1000 - -"
        "d '${cfg._home_node_dotn8n-files}' 0711 1000 1000 - -"
      ])
      enabled);

    virtualisation.oci-containers.containers = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.oci-container.name} = {
          inherit (cfg.modules.virtualisation.oci-containers.containers) image;
          autoStart = false;
          environmentFiles = [
            outerCfg.sops.secrets.${cfg.sops.envFile.key}.path
          ];
          environment = {
            N8N_PROXY_HOPS = toString (pkgs.myLib.countTrue [
              (cfg.modules.proxy-compose ? cloudflared)
              (cfg.modules.proxy-compose ? caddy)
            ]);
            N8N_PROTOCOL = "https";
            N8N_HOST = cfg.modules.proxy-compose.hostname;
            WEBHOOK_URL = "https://${cfg.modules.proxy-compose.hostname}/";
            N8N_PORT = toString cfg.port;
            NODE_ENV = "production";
            GENERIC_TIMEZONE = outerCfg.time.timeZone;
            TZ = outerCfg.time.timeZone;
            N8N_VERSION_NOTIFICATIONS_ENABLED = "false";
            N8N_TEMPLATES_ENABLED = "false";
            N8N_LISTEN_ADDRESS = cfg.host;
          };
          volumes = [
            "${cfg._home_node_dotn8n}:${in-container_home_node_dotn8n}"
            "${cfg._home_node_dotn8n-files}:${in-container_home_node_dotn8n-files}"
          ];
          extraOptions = ["--network=host"];
          # ports = let
          #   HOST =
          #     if hasInfix ":" cfg.host
          #     then "[${cfg.host}]"
          #     else cfg.host;
          #   PORT = toString cfg.port;
          # in ["${HOST}:${PORT}:${PORT}"];
        };
      })
      enabled);
  };
}
