{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (name: cfg: cfg.enable) outerCfg.myOpt.camofox-browser-oci;
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
          sleep-on-idle = mkOption {
            default = {};
            type = types.anything;
          };
          virtualisation.oci-containers.containers = mkOption {
            default = {};
            type = types.anything;
          };
        };
        sleep-on-idle-id = mkOption {
          type = types.singleLineStr;
          default = name;
        };
        netns-id = mkOption {
          type = types.nullOr types.singleLineStr;
        };
        oci-container.name = mkOption {
          type = types.singleLineStr;
          default = name;
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
        sleep-on-idle-cfg = mkOption {
          type = types.anything;
          default = outerCfg.myOpt.sleep-on-idle.${cfg.sleep-on-idle-id};
          readOnly = true;
        };
        url = mkOption {
          type = types.nullOr (types.strMatching "^http://[^/]+:[0-9]+$");
          default =
            if (cfg.netns-id == null)
            then "http://${pkgs.myLib.bracketIpv6 cfg.sleep-on-idle-cfg.endpoints.default.proxy.ip-socket}"
            else null;
          readOnly = true;
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    sops.secrets = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.sops.envFile.key} = {
          inherit (cfg.sops.envFile) sopsFile;
        };
      })
      enabled);

    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.sleep-on-idle-id} = mkMerge [
          cfg.modules.sleep-on-idle
          {
            enable = true;
            health-check.path = "/";
            endpoints.default = {
              origin = {
                host = cfg.oci-container-cfg.environment.CAMOFOX_BIND_HOST;
                port = toInt cfg.oci-container-cfg.environment.CAMOFOX_PORT;
              };
              proxy = mkMerge [
                {
                  inherit (cfg) netns-id;
                }
                (optionalAttrs (cfg.netns-id == null) {
                  inherit (cfg.modules.sleep-on-idle.endpoints.default.proxy) port;
                })
                (optionalAttrs (cfg.netns-id != null) {
                  inherit (cfg.modules.sleep-on-idle.endpoints.default.proxy) ip-socket;
                })
              ];
            };
            set-cgroup-parent = {
              systemd-services = [];
              oci-containers = [cfg.oci-container.name];
              nixos-containers = [];
            };
          }
        ];
      })
      enabled);

    systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: let
        inherit (cfg.oci-container-cfg.environment) CAMOFOX_UPLOADS_DIR;
      in [
        "d '${CAMOFOX_UPLOADS_DIR}' 0771 1000 0 - -"
      ])
      enabled);

    virtualisation.oci-containers.containers = mkMerge (mapAttrsToList (name: cfg: let
        inherit (cfg.modules.virtualisation.oci-containers.containers.environment) CAMOFOX_UPLOADS_DIR;
      in {
        ${cfg.oci-container.name} = mkMerge [
          cfg.modules.virtualisation.oci-containers.containers
          {
            autoStart = false;
            autoRemoveOnStop = true;
            inherit (cfg.modules.virtualisation.oci-containers.containers) image;
            environment = {
              inherit (cfg.modules.virtualisation.oci-containers.containers.environment) CAMOFOX_PORT CAMOFOX_UPLOADS_DIR;
              CAMOFOX_BIND_HOST = mkDefault "::1";
            };
            environmentFiles = [outerCfg.sops.secrets.${cfg.sops.envFile.key}.path];
            volumes = ["${CAMOFOX_UPLOADS_DIR}:${CAMOFOX_UPLOADS_DIR}"];
            extraOptions =
              [
                "--shm-size=2g"
                "--cap-drop=ALL"
                "--security-opt=no-new-privileges"
              ]
              ++ (optional (cfg.netns-id == null) "--network=host");
          }
        ];
      })
      enabled);

    myOpt.netns = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.netns-id} = {
          set-network-namespace = {
            oci-containers = [cfg.oci-container.name];
          };
        };
      })
      (filterAttrs (name: cfg: cfg.netns-id != null) enabled));
  };
}
