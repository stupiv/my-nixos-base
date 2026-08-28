{
  config,
  lib,
  ...
}:
with lib; let
  enabled-litellm-compose = filterAttrs (_: cfg: cfg.enable) config.myOpt.litellm-compose;
in {
  options.myOpt.litellm-compose = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        proxy-compose = mkOption {
          type = types.anything;
          default = {};
        };
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "container@${name}";
          readOnly = true;
        };
        shared-run-secrets = mkOption {
          type = types.singleLineStr;
          default = builtins.dirOf config.sops.secrets.${cfg.secretEnvironmentFile-key}.path;
          readOnly = true;
        };
        secretEnvironmentFile-key = mkOption {
          type = types.singleLineStr;
          default = "${name}/secretEnvironmentFile";
          readOnly = true;
        };
        litellm = {
          package = mkOption {
            type = types.package;
            example = literalExpression ''pkgs.litellm'';
          };
          stateDir = mkOption {
            type = types.singleLineStr;
            example = "/var/lib/<name>/litellm_v_";
          };
          settings = mkOption {
            type = types.anything;
            default = {};
            example = literalExpression ''
              {
                model_list = [
                  {
                    model_name = "gpt-4o-mini";
                    litellm_params = {
                      model = "openai/gpt-4o-mini";
                      api_key = "os.environ/OPENAI_API_KEY";
                    };
                  }
                ];
              }
            '';
          };
        };
      };
    }));
  };

  config = {
    sops.secrets =
      mapAttrs' (name: cfg: (nameValuePair cfg.secretEnvironmentFile-key (mkForce {})))
      enabled-litellm-compose;

    myOpt.proxy-compose = mkMerge (mapAttrsToList (
        name: cfg: (let
          containerCfg = config.containers.${name}.config;
        in {
          ${cfg.serviceName} = mkMerge [
            cfg.proxy-compose
            {
              localMode.port = mkDefault 19812;
              sleep-on-idle = {
                health-check.path = "/health/readiness";
                endpoints.default = {
                  origin.port = containerCfg.services.litellm.port;
                };
              };
            }
          ];
        })
      )
      enabled-litellm-compose);

    containers = mkMerge (mapAttrsToList (
        name: cfg: (let
          containerCfg = config.containers.${name}.config;
          outerCfg = config;
        in {
          ${name} = {
            bindMounts = {
              "/var/lib/private/litellm" = {
                # litellm systemd is using DynamicUser;
                hostPath = cfg.litellm.stateDir;
                isReadOnly = false;
              };
              ${cfg.shared-run-secrets} = {
                hostPath = cfg.shared-run-secrets;
                isReadOnly = false;
              };
            };
            config.imports = [
              ({config, ...}: let
                innerCfg = config;
              in {
                assertions = [
                  {assertion = innerCfg.systemd.services.litellm.serviceConfig.DynamicUser;} # because we are bind mounting at /var/lib/private/litellm
                ];

                services.litellm = {
                  inherit (cfg.litellm) package settings;
                  enable = true;
                  host = "0.0.0.0";
                  environmentFile = outerCfg.sops.secrets.${cfg.secretEnvironmentFile-key}.path;
                };
              })
            ];
          };
        })
      )
      enabled-litellm-compose);

    systemd.tmpfiles.rules = flatten (
      mapAttrsToList (name: cfg: [
        "d '${cfg.litellm.stateDir}' - - - - -"
      ])
      enabled-litellm-compose
    );
  };
}
