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
        modules = {
          virtualisation.oci-containers.containers = mkOption {
            type = types.submodule ({...}: {
              freeformType = types.anything;
              options = {
                environment = mkOption {
                  type = types.submodule ({...}: {
                    freeformType = types.anything;
                    options = {
                      CAMOFOX_BIND_HOST = mkOption {
                        type = types.singleLineStr;
                        default = "::1";
                      };
                      CAMOFOX_PORT = mkOption {
                        type = types.singleLineStr;
                        default = toString cfg.port;
                        readOnly = true;
                      };
                    };
                  });
                };
              };
            });
          };
          set-env-vars = mkOption {
            type = types.anything;
          };
        };
        port = mkOption {
          type = types.port;
        };
        sleep-on-idle-id = mkOption {
          type = types.nullOr types.singleLineStr;
        };
        netns-id = mkOption {
          type = types.nullOr types.singleLineStr;
        };
        oci-container.name = mkOption {
          type = types.anything;
        };
        sops.dotenv = {
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
        ${cfg.sops.dotenv.key} = {
          inherit (cfg.sops.dotenv) sopsFile;
        };
      })
      enabled);

    virtualisation.oci-containers.containers = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.oci-container.name} = mkMerge [
          cfg.modules.virtualisation.oci-containers.containers
          {
            inherit (cfg.modules.virtualisation.oci-containers.containers) image;
            autoStart = false;
            environmentFiles = [
              outerCfg.sops.secrets.${cfg.sops.dotenv.key}.path
            ];
            extraOptions =
              [
                "--shm-size=2g"
                "--read-only"
                "--cap-drop=ALL"
                "--security-opt=no-new-privileges"
                "--pids-limit=512"
              ]
              ++ optional (cfg.netns-id == null) "--network=host";
          }
        ];
      })
      enabled);

    myOpt.set-env-vars = mkMerge (mapAttrsToList (name: cfg: let
        inherit (pkgs.myLib) bracketIpv6;
        inherit (cfg.modules.virtualisation.oci-containers.containers.environment) CAMOFOX_BIND_HOST CAMOFOX_PORT;
      in {
        "camofox-${name}" = mkMerge [
          cfg.modules.set-env-vars
          {
            environment = {
              CAMOFOX_URL = "http://${bracketIpv6 "${CAMOFOX_BIND_HOST}:${CAMOFOX_PORT}"}";
            };
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
      (filterAttrs (_: cfg: cfg.netns-id != null) enabled));

    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.sleep-on-idle-id}.set-cgroup-parent = {
          oci-containers = [
            cfg.oci-container.name
          ];
        };
      })
      (filterAttrs (_: cfg: cfg.sleep-on-idle-id != null) enabled));
  };
}
