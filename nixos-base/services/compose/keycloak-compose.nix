{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (name: cfg: cfg.enable) outerCfg.myOpt.keycloak-compose;
in {
  options.myOpt.keycloak-compose = mkOption {
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
          keycloak = mkOption {
            type = types.anything;
            default = {};
          };
          postgresql = mkOption {
            type = types.anything;
            default = {};
          };
          proxy-compose = mkOption {
            type = types.anything;
            default = {};
          };
        };
        container.name = mkOption {
          type = types.singleLineStr;
          default = name;
        };
        database.port = mkOption {
          type = types.port;
        };
        proxy-compose-id = mkOption {
          type = types.singleLineStr;
          default = name;
        };
        keycloak-id = mkOption {
          type = types.singleLineStr;
          default = name;
        };
        sleep-on-idle-id = mkOption {
          type = types.singleLineStr;
          default = name;
        };
        sleep-on-idle-cfg = mkOption {
          type = types.anything;
          default = outerCfg.myOpt.sleep-on-idle.${cfg.sleep-on-idle-id};
          readOnly = true;
        };
        netns-id = mkOption {
          type = types.singleLineStr;
          default = name;
        };
      };
    }));
  };

  config = mkIf (enabled != {}) (mkMerge [
    (let
      mk-unix-socket = name: "/run/${name}/keycloak/keycloak.sock";
    in {
      myOpt.netns = mkMerge (mapAttrsToList (name: cfg: {
          ${cfg.netns-id}.enable = mkForce false;
        })
        enabled);

      myOpt.sleep-on-idle = mkMerge (mapAttrsToList (name: cfg: {
          ${cfg.sleep-on-idle-id} = {
            endpoints.default = {
              origin.ip-socket = mk-unix-socket name;
            };
          };
        })
        enabled);

      systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: [
          "d '${builtins.dirOf (mk-unix-socket name)}' 0711 root root - -"
        ])
        enabled);

      containers = mkMerge (mapAttrsToList (name: cfg: {
          ${cfg.container.name} = {
            extraFlags = [
              "--bind=${builtins.dirOf (mk-unix-socket name)}:${builtins.dirOf (mk-unix-socket name)}:rootidmap"
            ];
            privateNetwork = mkForce true;
            config = {config, ...} @ containerArgs: let
              containerCfg = containerArgs.config;
            in {
              imports = [
                ../systemd-socket-proxyd.nix
              ];
              myOpt.systemd-socket-proxyd."keycloak-proxy-${name}" = {
                origin = {
                  host = containerCfg.services.keycloak.settings.http-host;
                  port = containerCfg.services.keycloak.settings.http-port;
                  serviceName = "keycloak";
                };
                proxy.ip-socket = mk-unix-socket name;
              };
            };
          };
        })
        enabled);
    }) # See https://github.com/systemd/systemd/pull/41838
    {
      myOpt.netns = mkMerge (mapAttrsToList (name: cfg: {
          ${cfg.netns-id} = {
            enable = true;
            set-network-namespace = {
              systemd-services = [];
              oci-containers = [];
              nixos-containers = [cfg.container.name];
            };
          };
        })
        enabled);

      myOpt.proxy-compose = mapAttrs' (name: cfg:
        nameValuePair cfg.proxy-compose-id (mkMerge [
          cfg.modules.proxy-compose
          {
            enable = true;
            inherit (cfg) sleep-on-idle-id;
            modules.sleep-on-idle = {
              health-check.path = "/";
              endpoints.default = {
                origin = {
                  inherit (outerCfg.myOpt.keycloak.${cfg.keycloak-id}) host port;
                };
                proxy = {
                  inherit (cfg) netns-id;
                };
              };
              set-cgroup-parent.systemd-services = [];
              set-cgroup-parent.oci-containers = [];
              set-cgroup-parent.nixos-containers = [cfg.container.name];
            };
          }
        ]))
      enabled;

      containers = mkMerge (mapAttrsToList (name: cfg: {
          ${cfg.container.name} = {
            ephemeral = true;
            autoStart = false;
            privateUsers = "pick";
            privateNetwork = false;
            config.nixpkgs.pkgs = pkgs;
          };
        })
        enabled);

      myOpt.keycloak = mkMerge (mapAttrsToList (name: cfg: {
          ${cfg.keycloak-id} = mkMerge [
            cfg.modules.keycloak
            {
              enable = true;
              inherit (cfg) sleep-on-idle-id netns-id;
              container.name = cfg.container.name;
              modules.services.keycloak = {
                database = {
                  inherit (cfg.database) port;
                  type = "postgresql";
                  createLocally = false;
                  host = "/run/postgresql";
                };
                settings = {
                  hostname = "https://${cfg.modules.proxy-compose.hostname}";
                };
              };
            }
          ];
        })
        enabled);

      myOpt.postgresql = mapAttrs' (name: cfg:
        nameValuePair name (mkMerge [
          cfg.modules.postgresql
          {
            enable = true;
            inherit (cfg) sleep-on-idle-id netns-id;
            container.name = cfg.container.name;
            modules.services.postgresql = {
              settings = {
                inherit (cfg.database) port;
              };
              ensureDatabases = ["keycloak"];
              ensureUsers = [
                {
                  name = "keycloak";
                  ensureDBOwnership = true;
                }
              ];
            };
          }
        ]))
      enabled;
    }
  ]);
}
