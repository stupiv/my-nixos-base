{
  config,
  lib,
  pkgs,
  inputs,
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
          containers = mkOption {
            type = types.anything;
          };
          # camofox-browser-oci = mkOption {
          #   type = types.anything;
          # };
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
        camofox-browser-oci-id = mkOption {
          type = types.anything;
          default = name;
        };
        # camofox-plugin = mkOption {
        #   type = types.package;
        # };
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
            sops.dotenv = {inherit (cfg) sopsFile;};
            modules.services.hermes-agent = {
              # extraPlugins = [cfg.camofox-plugin];
              # settings = {
              #   browser.cloud_provider = "camofox";
              #   plugins.enabled = [ "camofox" ];
              # };
              # environment = {
              #   inherit (outerCfg.myOpt.camofox-browser-oci.${cfg.camofox-browser-oci-id}) CAMOFOX_URL;
              # };
            };
          }
        ];
      })
      enabled);

    # myOpt.camofox-browser-oci = mkMerge (mapAttrsToList (name: cfg: {
    #     ${cfg.camofox-browser-oci-id} = mkMerge [
    #       cfg.modules.camofox-browser-oci
    #       {
    #         enable = true;
    #         inherit (cfg) sleep-on-idle-id netns-id;
    #         oci-container.name = "camofox-browser-oci-${name}";
    #         modules = {
    #           # set-env-vars = {
    #           #   systemd-services = [];
    #           #   oci-containers = [];
    #           #   nixos-containers = [cfg.container.name];
    #           # };
    #           systemd.services = {
    #             before = [
    #               "container@${cfg.container.name}.service"
    #             ];
    #             after = [];
    #           };
    #         };
    #         sops.dotenv = {inherit (cfg) sopsFile;};
    #       }
    #     ];
    #   })
    #   enabled);

    containers = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.container.name} = mkMerge [
          cfg.modules.containers
          {
            ephemeral = true;
            autoStart = false;
            privateUsers = "pick";
            privateNetwork = false;
            config.nixpkgs.pkgs = pkgs;
          }
        ];
      })
      enabled);
  };
}
