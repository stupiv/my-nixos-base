{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  enabled = filterAttrs (_: cfg: cfg.enable) config.myOpt.plausible-compose;
in {
  options.myOpt.plausible-compose = mkOption {
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
          proxy-compose = mkOption {
            type = types.anything;
            default = {};
          };
        };
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "container@${name}";
          readOnly = true;
        };
        shared-run-secrets = mkOption {
          type = types.singleLineStr;
          default = builtins.dirOf config.sops.secrets.${cfg.secretKeybaseFile-key}.path;
          readOnly = true;
        };
        secretKeybaseFile-key = mkOption {
          type = types.singleLineStr;
          default = "${name}/secretKeybaseFile";
          readOnly = true;
        };
        plausible = {
          package = mkOption {
            type = types.package;
            example = literalExpression ''pkgs.plausible'';
          };
          stateDir = mkOption {
            type = types.singleLineStr;
            example = "/var/lib/<name>/plausible_v_";
          };
        };
        postgresql = {
          package = mkOption {
            type = types.package;
            example = literalExpression ''pkgs.postgresql_18'';
          };
          stateDir = mkOption {
            type = types.singleLineStr;
            example = "/var/lib/<name>/postgresql_v18";
          };
        };
        clickhouse = {
          package = mkOption {
            type = types.package;
            example = literalExpression ''pkgs.clickhouse-lts'';
          };
          stateDir = mkOption {
            type = types.singleLineStr;
            example = "/var/lib/<name>/clickhouse_v____";
          };
        };
      };
    }));
  };

  config = {
    sops.secrets =
      mapAttrs' (name: cfg: (nameValuePair cfg.secretKeybaseFile-key (mkForce {})))
      enabled;

    myOpt.proxy-compose = mkMerge (mapAttrsToList (
        name: cfg: (let
          containerCfg = config.containers.${name}.config;
        in {
          ${name} = mkMerge [
            cfg.modules.proxy-compose
            {
              enable = true;
              modules.sleep-on-idle = {
                health-check.path = "/api/system/health/ready";
                endpoints.default = {
                  origin.port = containerCfg.services.plausible.server.port;
                };
                set-cgroup-parent.systemd-services = [cfg.serviceName];
                set-cgroup-parent.oci-containers = [];
              };
            }
          ];
        })
      )
      enabled);

    containers = mkMerge (mapAttrsToList (
        name: cfg: (let
          containerCfg = config.containers.${name}.config;
          outerCfg = config;
        in {
          ${name} = {
            ephemeral = true;
            autoStart = false;
            config.nixpkgs.pkgs = pkgs;
            bindMounts = {
              "/var/lib/private/plausible" = {
                # plausible systemd is using DynamicUser;
                hostPath = cfg.plausible.stateDir;
                isReadOnly = false;
              };
              "/var/lib/${containerCfg.systemd.services.clickhouse.serviceConfig.StateDirectory}" = {
                hostPath = cfg.clickhouse.stateDir;
                isReadOnly = false;
              };
              ${containerCfg.services.postgresql.dataDir} = {
                hostPath = cfg.postgresql.stateDir;
                isReadOnly = false;
              };
              ${cfg.shared-run-secrets} = {
                hostPath = cfg.shared-run-secrets;
                isReadOnly = true;
              };
            };
            config.imports = [
              ({config, ...}: let
                innerCfg = config;
              in {
                assertions = [
                  {assertion = innerCfg.systemd.services.plausible.serviceConfig.DynamicUser;} # because we are bind mounting at /var/lib/private/plausible
                ];

                services.plausible = {
                  inherit (cfg.plausible) package;
                  enable = true;
                  database = {
                    postgres.setup = true;
                    clickhouse.setup = true;
                  };
                  server = {
                    baseUrl = "https://${cfg.proxy-compose.hostname}/";
                    secretKeybaseFile = outerCfg.sops.secrets.${cfg.secretKeybaseFile-key}.path;
                  };
                };
                services.postgresql = {
                  inherit (cfg.postgresql) package;
                };
                services.clickhouse = {
                  inherit (cfg.clickhouse) package;
                };
              })
            ];
          };
        })
      )
      enabled);

    systemd.tmpfiles.rules = flatten (
      mapAttrsToList (name: cfg: [
        "d '${cfg.plausible.stateDir}' - - - - -"
        "d '${cfg.clickhouse.stateDir}' - - - - -"
        "d '${cfg.postgresql.stateDir}' - - - - -"
      ])
      enabled
    );
  };
}
