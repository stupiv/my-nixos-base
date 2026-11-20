{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (name: cfg: cfg.enable) outerCfg.myOpt.hermes-agent;
in {
  options.myOpt.hermes-agent = mkOption {
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
          services.hermes-agent = mkOption {
            default = {};
            type = types.submodule ({...}: {
              freeformType = types.anything;
              options = {
                package = mkOption {
                  type = types.package;
                  default = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
                };
              };
            });
          };
          containers = mkOption {
            default = {};
            type = types.anything;
          };
        };
        container.name = mkOption {
          type = types.singleLineStr;
        };
        hermes-agent-cfg = mkOption {
          type = types.anything;
          default = outerCfg.containers.${cfg.container.name}.config.services.hermes-agent;
          readOnly = true;
        };
        host = mkOption {
          type = types.singleLineStr;
          default = cfg.hermes-agent-cfg.backend.host;
          readOnly = true;
        };
        port = mkOption {
          type = types.port;
          default = cfg.hermes-agent-cfg.backend.port;
          readOnly = true;
        };
        uid = mkOption {
          type = types.int;
        };
        gid = mkOption {
          type = types.int;
        };
        stateDir = mkOption {
          type = types.singleLineStr;
        };
        sleep-on-idle-id = mkOption {
          type = types.nullOr types.singleLineStr;
        };
        netns-id = mkOption {
          type = types.nullOr types.singleLineStr;
        };
        camofox-browser-oci-id = mkOption {
          type = types.nullOr types.singleLineStr;
        };
        camofox-browser-oci-cfg = mkOption {
          type = types.anything;
          default = outerCfg.myOpt.camofox-browser-oci.${cfg.camofox-browser-oci-id};
          readOnly = true;
        };
        camofox-browser.enable = mkOption {
          type = types.bool;
          default = cfg.camofox-browser-oci-id != null;
          readOnly = true;
        };
        cdp-compose-id = mkOption {
          type = types.nullOr types.singleLineStr;
          default = null;
        };
        cdp-compose-cfg = mkOption {
          type = types.anything;
          default = outerCfg.myOpt.cdp-compose.${cfg.cdp-compose-id};
          readOnly = true;
        };
        cdp.enable = mkOption {
          type = types.bool;
          default = cfg.cdp-compose-id != null;
          readOnly = true;
        };
        sops.envFile = {
          key = mkOption {
            type = types.singleLineStr;
          };
          sopsFile = mkOption {
            type = types.path;
          };
          path = mkOption {
            type = types.strMatching "^/run/.*[^/]$";
            default = outerCfg.sops.secrets.${cfg.sops.envFile.key}.path;
            readOnly = true;
          };
        };
        lightpanda = {
          enable = mkOption {
            type = types.bool;
            default = !cfg.camofox-browser.enable && !cfg.cdp.enable;
            readOnly = true;
          };
          package = mkOption {
            type = types.package;
            default = inputs.lightpanda.packages.${pkgs.stdenv.hostPlatform.system}.default;
          };
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    assertions = flatten (mapAttrsToList (name: cfg: [
        {
          assertion = !cfg.camofox-browser.enable || (cfg.netns-id == cfg.camofox-browser-oci-cfg.netns-id);
          message = "assertion = !cfg.camofox-browser.enable || (cfg.netns-id == cfg.camofox-browser-oci-cfg.netns-id);";
        }
        {
          assertion = !cfg.cdp.enable || (cfg.netns-id == cfg.cdp-compose-cfg.netns-id);
          message = "assertion = !cfg.cdp.enable || (cfg.netns-id == cfg.cdp-compose-cfg.netns-id);";
        }
      ])
      enabled);

    sops.useTmpfs = true;
    sops.secrets = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.sops.envFile.key} = {
          inherit (cfg.sops.envFile) sopsFile;
          restartUnits = ["container@${name}.service"];
        };
      })
      enabled);

    systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: [
        "d '${cfg.stateDir}' 0711 ${toString cfg.uid} ${toString cfg.gid} - -"
      ])
      enabled);

    containers = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.container.name} = mkMerge [
          cfg.modules.containers
          {
            extraFlags = [
              "--bind=${cfg.stateDir}:${cfg.stateDir}:idmap"
              "--bind-ro=${cfg.sops.envFile.path}:${cfg.sops.envFile.path}:rootidmap"
            ];
            config = {...}: {
              imports = [
                inputs.hermes-agent.nixosModules.default
              ];

              programs.nix-ld.enable = false;
              environment.systemPackages = cfg.hermes-agent-cfg.extraPackages;

              users.users.${cfg.hermes-agent-cfg.user}.uid = cfg.uid;
              users.groups.${cfg.hermes-agent-cfg.group}.gid = cfg.gid;
              services.hermes-agent = mkMerge [
                cfg.modules.services.hermes-agent
                (optionalAttrs (cfg.camofox-browser.enable) {
                  settings = {
                    browser.cloud_provider = "camofox";
                    plugins.enabled = ["camofox"];
                  };
                  environment = {
                    CAMOFOX_URL = cfg.camofox-browser-oci-cfg.url;
                  };
                })
                (optionalAttrs (cfg.cdp.enable) {
                  settings = {
                    browser.cdp_url = cfg.cdp-compose-cfg.url;
                  };
                })
                (optionalAttrs (!cfg.cdp.enable) {
                  settings = {
                    browser.cdp_url = "";
                  };
                })
                (optionalAttrs (cfg.lightpanda.enable) {
                  settings = {
                    browser.cloud_provider = "local";
                    browser.engine = "lightpanda";
                  };
                  extraPackages = [cfg.lightpanda.package];
                })
                (optionalAttrs (!cfg.lightpanda.enable) {
                  settings = {
                    browser.engine = "";
                  };
                })
                {
                  enable = true;
                  inherit (cfg) stateDir;
                  package = mkDefault cfg.modules.services.hermes-agent.package;
                  environmentFiles = [cfg.sops.envFile.path];
                  backend = {
                    inherit (cfg.modules.services.hermes-agent.backend) port;
                    host = mkDefault "::1";
                    mode = mkDefault "serve";
                  };
                  addToSystemPackages = true;
                }
              ];
            };
          }
        ];
      })
      enabled);

    myOpt.netns = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.netns-id} = {
          set-network-namespace = {
            nixos-containers = [cfg.container.name];
          };
        };
      })
      (filterAttrs (name: cfg: cfg.netns-id != null) enabled));

    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.sleep-on-idle-id} = {
          set-cgroup-parent = {
            nixos-containers = [cfg.container.name];
          };
        };
      })
      (filterAttrs (name: cfg: cfg.sleep-on-idle-id != null) enabled));
  };
}
