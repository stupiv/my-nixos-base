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
            type = types.anything;
          };
        };
        set-env-vars = mkOption {
          type = types.anything;
        };
        oci-container-cfg = mkOption {
          type = types.anything;
          default = outerCfg.virtualisation.oci-containers.containers.${cfg.container.name};
          readOnly = true;
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
            inherit (cfg.modules.virtualisation.oci-containers.containers) image;
            autoStart = false;
            environment = {
              inherit (cfg.modules.virtualisation.oci-containers.containers.environment) CAMOFOX_BIND_HOST CAMOFOX_PORT;
            };
            environmentFiles = [
              cfg.sops.envfile.cfg.path
            ];
            extraOptions = [
              "--shm-size=2g"
              "--read-only"
              "--cap-drop=ALL"
              "--security-opt=no-new-privileges"
              "--pids-limit=512"
            ] ++ optional (cfg.netns-id == null) "--network=host";
          }
        ];
      })
      enabled);

    myOpt.set-env-vars = mkMerge (mapAttrsToList (name: cfg: let
        inherit (pkgs.myLib) bracketIpv6;
        inherit (oci-container-cfg.environment) CAMOFOX_BIND_HOST CAMOFOX_PORT;
      in {
        "camofox-${name}" = {
          inherit (cfg.set-env-vars) systemd-services nixos-containers oci-containers;
          environment = {
            CAMOFOX_URL = "http://${bracketIpv6 "${CAMOFOX_BIND_HOST}:${CAMOFOX_PORT}"}";
          };
        };
      })
      enabled);

    myOpt.netns = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.netns-id}.set-network-namespace = {
          oci-containers = [
            cfg.oci-container.name
          ];
        };
      })
      (fiterAttrs (_: cfg: cfg.netns-id != null) enabled));

    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.sleep-on-idle-id}.set-cgroup-parent = {
          oci-containers = [
            cfg.oci-container.name
          ];
        };
      })
      (fiterAttrs (_: cfg: cfg.sleep-on-idle-id != null) enabled));
  };
}
