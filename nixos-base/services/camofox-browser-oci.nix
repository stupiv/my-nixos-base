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
            default = {};
            type = types.submodule ({...}: {
              freeformType = types.anything;
              options = {
                environment = mkOption {
                  type = types.submodule ({...}: {
                    freeformType = types.anything;
                    options = {
                      # CAMOFOX_BIND_HOST = mkOption {
                      #   type = types.singleLineStr;
                      #   default = "::1";
                      # };
                      # CAMOFOX_PORT = mkOption {
                      #   type = types.singleLineStr;
                      #   default = toString cfg.port;
                      #   readOnly = true;
                      # };
                    };
                  });
                };
              };
            });
          };
          # systemd.services = mkOption {
          #   default = {};
          #   type = types.anything;
          # };
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
        sops.envFile = {
          key = mkOption {
            type = types.anything;
          };
          sopsFile = mkOption {
            type = types.anything;
          };
        };
        oci-container-cfg = mkOption {
          type = types.anything;
          default = outerCfg.virtualisation.oci-containers.containers.${cfg.oci-container.name};
          readOnly = true;
        };
        # host = mkOption {
        #   type = types.singleLineStr;
        #   default = "::1";
        # };
        # port = mkOption {
        #   type = types.port;
        # };
        host = mkOption {
          type = types.singleLineStr;
          default = cfg.oci-container-cfg.environment.CAMOFOX_BIND_HOST;
          readOnly = true;
        };
        port = mkOption {
          type = types.singleLineStr;
          default = cfg.oci-container-cfg.environment.CAMOFOX_PORT;
          readOnly = true;
        };
        # url = mkOption {
        #   type = types.singleLineStr;
        #   default = let
        #     inherit (pkgs.myLib) bracketIpv6;
        #     # inherit (cfg.modules.virtualisation.oci-containers.containers.environment) CAMOFOX_BIND_HOST CAMOFOX_PORT;
        #     inherit (cfg.oci-container-cfg.environment) CAMOFOX_BIND_HOST CAMOFOX_PORT;
        #   in "http://${bracketIpv6 "${CAMOFOX_BIND_HOST}:${CAMOFOX_PORT}"}";
        #   readOnly = true;
        # };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    sops.secrets = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.sops.envFile.key} = {
          inherit (cfg.sops.envFile) sopsFile;
        };
      })
      enabled);

    virtualisation.oci-containers.containers = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.oci-container.name} = mkMerge [
          cfg.modules.virtualisation.oci-containers.containers
          {
            inherit (cfg.modules.virtualisation.oci-containers.containers) image;
            autoStart = false;
            environmentFiles = [outerCfg.sops.secrets.${cfg.sops.envFile.key}.path];
            environment = {
              inherit (cfg.modules.virtualisation.oci-containers.containers.environment) CAMOFOX_PORT;
              CAMOFOX_BIND_HOST = mkDefault "::1";
              # CAMOFOX_DISABLE_DEFAULT_ADDONS = "1";
              # CAMOFOX_BIND_HOST = cfg.host;
              # CAMOFOX_PORT = toString cfg.port;
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

    # systemd.services = mkMerge (mapAttrsToList (_: cfg: {
    #     ${outerCfg.virtualisation.oci-containers.containers.${cfg.oci-container.name}.serviceName} = mkMerge [
    #       cfg.modules.systemd.services
    #       {
    #         inherit (cfg.modules.systemd.services) before after;
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
