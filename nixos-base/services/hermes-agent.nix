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
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        sleep-on-idle = mkOption {
          type = types.anything;
          default = {};
        };
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "container@${name}";
          readOnly = true;
        };
        vpnNamespace = mkOption {
          type = types.singleLineStr;
          default = name;
          readOnly = true;
        };
        secretsDirName = mkOption {
          type = types.singleLineStr;
          default = name;
          readOnly = true;
        };
        containerName = mkOption {
          type = types.singleLineStr;
          default = name;
          readOnly = true;
        };
        socketDir = mkOption {
          type = types.singleLineStr;
          default = "/run/sockets/${name}";
          readOnly = true;
        };
        secretsDir = mkOption {
          type = types.singleLineStr;
          default = builtins.dirOf outerCfg.sops.secrets.${cfg.wireguardConfigFile-key}.path;
          readOnly = true;
        };
        wireguardConfigFile-key = mkOption {
          type = types.singleLineStr;
          default = "${cfg.secretsDirName}/wireguardConfigFile";
          readOnly = true;
        };
        port = mkOption {
          type = types.port;
        };
        hermes-agent = {
          stateDir = mkOption {
            type = types.singleLineStr;
          };
          port = mkOption {
            type = types.port;
          };
          envFile-key = mkOption {
            type = types.singleLineStr;
            default = "${cfg.secretsDirName}/hermes-agent-envFile";
            readOnly = true;
          };
          ip-socket = mkOption {
            type = types.singleLineStr;
            default = "${cfg.socketDir}/hermes-agent.sock";
            readOnly = true;
          };
        };
        litellm = {
          stateDir = mkOption {
            type = types.singleLineStr;
          };
          port = mkOption {
            type = types.port;
          };
          envFile-key = mkOption {
            type = types.singleLineStr;
            default = "${cfg.secretsDirName}/litellm-envFile";
            readOnly = true;
          };
          ip-socket = mkOption {
            type = types.singleLineStr;
            default = "${cfg.socketDir}/litellm.sock";
            readOnly = true;
          };
        };
      };
    }));
  };

  imports = [
    inputs.vpn-confinement.nixosModules.default
  ];

  config = mkIf (enabled != {}) {
    sops.secrets = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.wireguardConfigFile-key} = mkForce {};
        ${cfg.litellm.envFile-key} = mkForce {};
        ${cfg.hermes-agent.envFile-key} = mkForce {};
      })
      enabled);

    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (
        _: cfg: {
          ${cfg.serviceName} = mkMerge [
            cfg.sleep-on-idle
            {
              health-check.path = "/";
              endpoints = {
                default = {
                  # hermes-agent = {
                  origin.socket-address = cfg.hermes-agent.ip-socket;
                  proxy.port = cfg.hermes-agent.port;
                };
                litellm = {
                  origin.socket-address = cfg.litellm.ip-socket;
                  proxy.port = cfg.litellm.port;
                };
              };
            }
          ];
        }
      )
      enabled);

    containers = mkMerge (mapAttrsToList (
        _: cfg: (let
          containerCfg = outerCfg.containers.${cfg.containerName}.config;
        in {
          ${cfg.containerName} = {
            ephemeral = true;
            privateNetwork = ! outerCfg.vpnNamespaces.${cfg.vpnNamespace}.enable;
            autoStart = false;
            bindMounts = {
              ${containerCfg.services.hermes-agent.stateDir} = {
                hostPath = cfg.hermes-agent.stateDir;
                isReadOnly = false;
              };
              ${containerCfg.services.litellm.stateDir} = {
                hostPath = cfg.litellm.stateDir;
                isReadOnly = false;
              };
              ${cfg.secretsDir} = {
                hostPath = cfg.secretsDir;
                isReadOnly = true;
              };
              ${cfg.socketDir} = {
                hostPath = cfg.socketDir;
                isReadOnly = false;
              };
            };
            config = {
              imports = [inputs.hermes-agent.nixosModules.default];

              myOpt.systemd-socket-proxyd = {
                hermes-agent = {
                  origin.tcp-port = containerCfg.services.hermes-agent.backend.port;
                  proxy.ip-socket = cfg.hermes-agent.ip-socket;
                };
                litellm = {
                  origin.tcp-port = containerCfg.services.litellm.port;
                  proxy.ip-socket = cfg.litellm.ip-socket;
                };
              };

              services.litellm = {
                enable = true;
                stateDir = cfg.litellm.stateDir;
                port = cfg.litellm.port;
                environmentFile = outerCfg.sops.secrets.${cfg.litellm.envFile-key}.path;
              };
              services.hermes-agent = {
                enable = true;
                stateDir = cfg.hermes-agent.stateDir;
                backend.mode = "dashboard";
                backend.port = cfg.hermes-agent.port;
                environmentFiles = [outerCfg.sops.secrets.${cfg.hermes-agent.envFile-key}.path];
                settings = {
                  display.busy_input_mode = "steer";
                  model = {
                    default = "";
                    provider = "";
                    base_url = "";
                    api_mode = "";
                  };
                  agent = {
                    reasoning_effort = "";
                    service_tier = "";
                  };
                };
              };
            };
          };
        })
      )
      enabled);

    vpnNamespaces = mkMerge (mapAttrsToList (
        _: cfg: {
          ${cfg.vpnNamespace} = {
            enable = true;
            wireguardConfigFile = outerCfg.sops.secrets.${cfg.wireguardConfigFile-key}.path;
          };
        }
      )
      enabled);

    systemd.services =
      mapAttrs' (_: cfg: (nameValuePair cfg.serviceName {
        vpnConfinement = {
          enable = true;
          inherit (cfg) vpnNamespace;
        };
      }))
      enabled;

    systemd.tmpfiles.rules = flatten (
      mapAttrsToList (_: cfg: [
        "d '${cfg.hermes-agent.stateDir}' - - - - -"
        "d '${cfg.litellm.stateDir}' - - - - -"
        "d '${cfg.socketDir}' - - - - -"
      ])
      enabled
    );
  };
}
