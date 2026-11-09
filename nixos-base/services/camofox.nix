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
          type = types.submodule ({...}: {
            freeformType = types.anything;
            options = {
              image = mkOption {
                type = types.anything;
                # See https://github.com/jo-inc/camofox-browser/pkgs/container/camofox-browser
              };
              environment = mkOption {
                freeformType = types.anything;
                type = types.submodule ({...}: {
                  options = {
                    CAMOFOX_BIND_HOST = mkOption {
                      type = types.anything;
                    };
                    CAMOFOX_PORT = mkOption {
                      type = types.anything;
                    };
                    HTTP_PROXY = mkOption {
                      type = types.strMatching "^http.+[^/]$";
                    };
                    HTTPS_PROXY = mkOption {
                      type = types.strMatching "^http.+[^/]$";
                    };
                    NO_PROXY = mkOption {
                      type = types.singleLineStr;
                      default = "localhost,127.0.0.1,::1";
                    };
                  };
                });
              };
            };
          });
        };
        netns-id = mkOption {
          type = types.anything;
        };
        sleep-on-idle-id = mkOption {
          type = types.anything;
        };
        oci-container.name = mkOption {
          type = types.anything;
        };
        sops.envfile = {
          cfg = mkOption {
            type = types.anything;
            default = outerCfg.sops.secrets.${cfg.sops.envfile.key};
            readOnly = true;
          };
          key = mkOption {
            type = types.anything;
          };
          sopsFile = mkOption {
            type = types.anything;
          };
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    sops.secrets = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.sops.envfile.key} = {
          inherit (cfg.sops.envfile) sopsFile;
        };
      })
      enabled);

    virtualisation.oci-containers.containers = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.oci-container.name} = mkMerge [
          cfg.modules.virtualisation.oci-containers.containers
          {
            autoStart = false;
            environmentFiles = [
              cfg.sops.envfile.cfg.path
            ];
            extraOptions = [
              "--shm-size=2g"
              "--read-only"
              "--cap-drop=ALL"
              "--security-opt=no-new-privileges"
              "--pids-limit=512"
            ];
          }
        ];
      })
      enabled);

    myOpt.netns = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.netns-id}.set-network-namespace = {
          oci-containers = [
            cfg.oci-container.name
          ];
        };
      })
      enabled);

    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.sleep-on-idle-id}.set-cgroup-parent = {
          oci-containers = [
            cfg.oci-container.name
          ];
        };
      })
      enabled);
  };
}
