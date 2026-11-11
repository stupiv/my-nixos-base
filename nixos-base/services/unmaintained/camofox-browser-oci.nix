{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.camofox-browser-oci;
in {
  options.myOpt.camofox-browser-oci = mkOption {
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
          # set-env-vars = mkOption {
          #   type = types.anything;
          # };
          systemd.services = mkOption {
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
        # uboDir = mkOption {
        #   type = types.singleLineStr;
        # };
        CAMOFOX_URL = mkOption {
          type = types.singleLineStr;
          default = let
            inherit (pkgs.myLib) bracketIpv6;
            inherit (cfg.modules.virtualisation.oci-containers.containers.environment) CAMOFOX_BIND_HOST CAMOFOX_PORT;
          in "http://${bracketIpv6 "${CAMOFOX_BIND_HOST}:${CAMOFOX_PORT}"}";
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    sops.secrets = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.sops.dotenv.key} = {
          inherit (cfg.sops.dotenv) sopsFile;
          # restartUnits = [];
        };
      })
      enabled);

    # systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: [
    #     "d ${cfg.uboDir} 0755 0 0 - -"
    #   ])
    #   enabled);

    virtualisation.oci-containers.containers = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.oci-container.name} = mkMerge [
          cfg.modules.virtualisation.oci-containers.containers
          {
            inherit (cfg.modules.virtualisation.oci-containers.containers) image;
            autoStart = false;
            environmentFiles = [outerCfg.sops.secrets.${cfg.sops.dotenv.key}.path];
            # volumes = ["${cfg.uboDir}:/root/.cache/camoufox/addons/UBO"];
            environment = {
              CAMOFOX_DISABLE_DEFAULT_ADDONS = "1";
            };
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

    systemd.services = mkMerge (mapAttrsToList (_: cfg: {
        ${outerCfg.virtualisation.oci-containers.containers.${cfg.oci-container.name}.serviceName} = mkMerge [
          cfg.modules.systemd.services
          {
            inherit (cfg.modules.systemd.services) before after;
          }
        ];
      })
      enabled);

    # myOpt.set-env-vars = mkMerge (mapAttrsToList (name: cfg: let
    #     inherit (pkgs.myLib) bracketIpv6;
    #     inherit (cfg.modules.virtualisation.oci-containers.containers.environment) CAMOFOX_BIND_HOST CAMOFOX_PORT;
    #   in {
    #     "camofox-browser-oci-${name}" = mkMerge [
    #       cfg.modules.set-env-vars
    #       {
    #         environment = {
    #           CAMOFOX_URL = "http://${bracketIpv6 "${CAMOFOX_BIND_HOST}:${CAMOFOX_PORT}"}";
    #         };
    #       }
    #     ];
    #   })
    #   enabled);

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
