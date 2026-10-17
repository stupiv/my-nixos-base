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
        sopsFile = mkOption {
          type = types.anything;
        };
        vpnNamespace = mkOption {
          type = types.anything;
          default =
            if builtins.stringLength name < 8
            then name
            else "v${builtins.substring 0 6 (builtins.hashString "sha256" name)}";
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
        camofox = {
          serviceName = mkOption {
            type = types.singleLineStr;
            default = "${cfg.containerName}-camofox";
            readOnly = true;
          };
          image = mkOption {
            type = types.singleLineStr;
            example = "ghcr.io/jo-inc/camofox-browser:1.18.1";
          };
          envFile-key = mkOption {
            type = types.singleLineStr;
            default = "${cfg.secretsDirName}/camofox-envFile";
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
        # firecrawl = {
        #   serviceName = mkOption {
        #     type = types.singleLineStr;
        #     default = "${cfg.containerName}-firecrawl";
        #     readOnly = true;
        #   };
        #   image = mkOption {
        #     type = types.singleLineStr;
        #     example = "ghcr.io/firecrawl/firecrawl:2.11.531-production";
        #   };
        #   port = mkOption {
        #     type = types.port;
        #   };
        #   envFile-key = mkOption {
        #     type = types.singleLineStr;
        #     default = "${cfg.secretsDirName}/firecrawl-envFile";
        #     readOnly = true;
        #   };
        # };
      };
    }));
  };

  imports = [
    inputs.vpn-confinement.nixosModules.default
  ];

  config = mkIf (enabled != {}) {
    sops.secrets = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.wireguardConfigFile-key} = {inherit (cfg) sopsFile;};
        ${cfg.hermes-agent.envFile-key} = {inherit (cfg) sopsFile;};
        ${cfg.camofox.envFile-key} = {inherit (cfg) sopsFile;};
        ${cfg.litellm.envFile-key} = {inherit (cfg) sopsFile;};
        # ${cfg.firecrawl.envFile-key} =  {inherit (cfg) sopsFile;};
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

    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers = mkMerge (mapAttrsToList
      (_: cfg: let
        commonAttrs = {
          autoStart = false;
          networks = ["ns:/run/netns/${cfg.vpnNamespace}"];
          volumes = [
            "/etc/netns/${cfg.vpnNamespace}/resolv.conf:/etc/resolv.conf:ro"
          ];
        };
      in {
        ${cfg.camofox.serviceName} =
          commonAttrs
          // {
            inherit (cfg.camofox) serviceName image;
            environment = {
              CAMOFOX_BIND_HOST = "::1";
            };
            environmentFiles = [outerCfg.sops.secrets.${cfg.camofox.envFile-key}.path];
            extraOptions = [
              "--shm-size=2g" # Firefox needs real shared memory; the default 64MB is not enough
            ];
          };
        # ${cfg.firecrawl.serviceName} =
        #   commonAttrs
        #   // {
        #     inherit (cfg.firecrawl) serviceName image;
        #     environment = {
        #       PORT = toString cfg.firecrawl.port;
        #       HOST = "0.0.0.0";
        #     };
        #     environmentFiles = [outerCfg.sops.secrets.${cfg.firecrawl.envFile-key}.path];
        #     # NOTE: the full self-hosted Firecrawl stack is a compose file
        #     # (API + workers + Playwright + Redis + RabbitMQ + PostgreSQL);
        #     # this runs only the API image.
        #   };
      })
      enabled);

    containers = mkMerge (mapAttrsToList (
        _: cfg: {
          ${cfg.containerName} = {
            ephemeral = true;
            privateNetwork = false;
            networkNamespace = "/run/netns/${cfg.vpnNamespace}";
            autoStart = false;
            bindMounts = {
              ${cfg.hermes-agent.stateDir} = {
                hostPath = cfg.hermes-agent.stateDir;
                isReadOnly = false;
              };
              ${cfg.litellm.stateDir} = {
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
              "/etc/resolv.conf" = {
                hostPath = "/etc/netns/${cfg.vpnNamespace}/resolv.conf";
                isReadOnly = true;
              };
            };
            config = {config, ...}: {
              imports = [
                inputs.hermes-agent.nixosModules.default
                ../systemd-socket-proxyd.nix
              ];
              myOpt.systemd-socket-proxyd = {
                hermes-agent = {
                  origin.ip-socket = "[::1]:${tostring cfg.hermes-agent.port}";
                  proxy.ip-socket = cfg.hermes-agent.ip-socket;
                };
                litellm = {
                  origin.ip-socket = "[::1]:${tostring cfg.litellm.port}";
                  proxy.ip-socket = cfg.litellm.ip-socket;
                };
              };
              services.litellm = {
                enable = true;
                stateDir = cfg.litellm.stateDir;
                port = cfg.litellm.port;
                host = "::1";
                environmentFile = outerCfg.sops.secrets.${cfg.litellm.envFile-key}.path;
              };
              services.hermes-agent = {
                enable = true;
                stateDir = cfg.hermes-agent.stateDir;
                backend.mode = "serve";
                backend.port = cfg.hermes-agent.port;
                backend.host = "::1";
                environmentFiles = [outerCfg.sops.secrets.${cfg.hermes-agent.envFile-key}.path];
                settings = {
                  browser = {
                    backend = "off";
                    cloud_provider = "camofox";
                    cdp_url = "";
                    extension_control.enabled = false;
                  }; # Force (self-hosted) Camofox
                  security.allow_lazy_installs = false; # Force no browser install
                  web = {
                    backend = "firecrawl";
                    search_backend = "firecrawl";
                    extract_backend = "firecrawl";
                  }; # Force (self-hosted) Firecrawl
                  display.busy_input_mode = "steer";
                  model = {
                    default = "";
                    provider = "";
                    base_url = "";
                    api_mode = "";
                  };
                  agent = {
                    reasoning_effort = "none"; # More secure (AI safety), efficient and fast
                    service_tier = "";
                  };
                  telemetry.shared_metrics = {
                    enabled = true;
                    send = true;
                  };
                  moa.presets.default.enabled = false;
                };
              };
            };
          };
        }
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

    networking.enableIPv6 = true;
    systemd.services = mkMerge (mapAttrsToList
      (_: cfg: {
        ${cfg.serviceName} = {
          bindsTo = ["${cfg.vpnNamespace}.service"];
          after = ["${cfg.vpnNamespace}.service"];
          wants = [
            "${cfg.camofox.serviceName}.service"
            # "${cfg.firecrawl.serviceName}.service"
          ];
        };
        ${cfg.camofox.serviceName} = {
          bindsTo = ["${cfg.vpnNamespace}.service"];
          after = ["${cfg.vpnNamespace}.service"];
        };
        # ${cfg.firecrawl.serviceName} = {
        #   bindsTo = ["${cfg.vpnNamespace}.service"];
        #   after = ["${cfg.vpnNamespace}.service"];
        # };
        "drop-ipv4-in-${cfg.vpnNamespace}-ns" = {
          vpnConfinement = {
            enable = true;
            inherit (cfg) vpnNamespace;
          };
          wantedBy = ["${cfg.vpnNamespace}.service"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            ${pkgs.nftables}/bin/nft -f ${pkgs.writeText "drop-ipv4.nft" ''
              table ip filter {
                chain output {
                  type filter hook output priority 0;
                  policy drop;
                }
                chain input {
                  type filter hook input priority 0;
                  policy drop;
                }
                chain forward {
                  type filter hook forward priority 0;
                  policy drop;
                }
              }
            ''}
          '';
        };
      })
      enabled);

    systemd.tmpfiles.rules = flatten (
      mapAttrsToList (_: cfg: [
        "d '${cfg.hermes-agent.stateDir}' - - - - -"
        "d '${cfg.socketDir}' - - - - -"
        "d '${cfg.litellm.stateDir}' - - - - -"
      ])
      enabled
    );
  };
}
