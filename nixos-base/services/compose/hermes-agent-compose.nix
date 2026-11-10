{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.hermes-agent-compose;
in {
  options.myOpt.hermes-agent-compose = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...}: {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        modules = {
          sleep-on-idle = mkOption {
            type = types.anything;
          };
          hermes-agent = mkOption {
            type = types.anything;
          };
          camofox = mkOption {
            type = types.anything;
          };
        };
        container.name = mkOption {
          type = types.singleLineStr;
          default = name;
        };
        sopsFile = mkOption {
          type = types.anything;
        };
        sleep-on-idle-id = mkOption {
          type = types.singleLineStr;
          default = name;
        };
        netns-id = mkOption {
          type = types.anything;
          default = null;
          readOnly = true;
        };
        hermes-agent-id = mkOption {
          type = types.anything;
          default = name;
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.sleep-on-idle-id} = mkMerge [
          cfg.modules.sleep-on-idle
          {
            enable = true;
            health-check.path = "/";
            endpoints.default.origin = {
              inherit (outerCfg.myOpt.hermes-agent.${cfg.hermes-agent-id}) host port;
            };
          }
        ];
      })
      enabled);

    myOpt.hermes-agent = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.hermes-agent-id} = mkMerge [
          cfg.modules.hermes-agent
          {
            enable = true;
            inherit (cfg) sleep-on-idle-id netns-id;
            container = {
              inherit (cfg.container) name;
            };
            modules.services.hermes-agent.settings = {
              browser.cloud_provider = "camofox";
            };
            sops.dotenv = {inherit (cfg) sopsFile;};
          }
        ];
      })
      enabled);

    myOpt.camofox = mkMerge (mapAttrsToList (name: cfg: {
        ${name} = mkMerge [
          cfg.modules.camofox
          {
            enable = true;
            inherit (cfg) sleep-on-idle-id netns-id;
            oci-container.name = "camofox-${name}";
            modules.set-env-vars = {
              systemd-services = [];
              oci-containers = [];
              nixos-containers = [cfg.container.name];
            };
            sops.dotenv = {inherit (cfg) sopsFile;};
          }
        ];
      })
      enabled);

    containers = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.container.name} = {
          ephemeral = true;
          autoStart = false;
          config.nixpkgs.pkgs = pkgs;
          privateUsers = "pick";
          privateNetwork = false;
        };
      })
      enabled);
  };
}
