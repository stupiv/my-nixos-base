{
  config,
  lib,
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
        hermes-agent-cfg = mkOption {
          type = types.anything;
          default = outerCfg.myOpt.hermes-agent;
          readOnly = true;
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    myOpt.hermes-agent = mapAttrs' (name: cfg:
      nameValuePair name (mkMerge [
        cfg.modules.hermes-agent
        {
          enable = true;
          inherit (cfg) sleep-on-idle-id netns-id;
          container = {
            inherit (cfg.container) name;
          };
          modules.service.hermes-agent.settings = {
            browser.cloud_provider = "camofox";
          };
        }
      ]))
    enabled;

    myOpt.camofox = mapAttrs' (name: cfg:
      nameValuePair name (mkMerge [
        cfg.modules.camofox
        {
          enable = true;
          inherit (cfg) sleep-on-idle-id netns-id;
          oci-container.name = "camofox-${name}";
          set-env-vars = {
            systemd-services = [];
            oci-containers = [];
            nixos-containers = [cfg.container.name];
          };
        }
      ]))
    enabled;

    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.sleep-on-idle-id} = mkMerge [
          cfg.modules.sleep-on-idle
          {
            enable = true;
            health-check.path = "/";
            endpoints.default = {
              inherit (hermes-agent-cfg) host port;
            };
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
