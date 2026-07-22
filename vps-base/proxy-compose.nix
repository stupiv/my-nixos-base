{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  enabled-cloudflared-proxy-compose = filterAttrs (name: cfg: cfg.cloudflared.enable) config.myOpt.proxy-compose;

  to-caddy-socket-address = socket-address: (
    if (hasPrefix "/" socket-address)
    then "unix/${socket-address}"
    else socket-address
  );
in {
  options.myOpt.proxy-compose = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        localMode = {
          enable = mkOption {
            type = types.bool;
            default = false;
          };
          ip-address = mkOption {
            type = types.singleLineStr;
            default = "localhost";
          };
          port = mkOption {
            type = types.port;
          };
          ip-socket = mkOption {
            type = types.singleLineStr;
            default = "${cfg.localMode.ip-address}:${toString cfg.localMode.port}";
          };
        };
        serviceName = mkOption {
          type = types.singleLineStr;
          default = name;
          readOnly = true;
        };
        containerName = mkOption {
          type = types.nullOr types.singleLineStr;
          default = let
            matches = builtins.match "^container@(.*)" cfg.serviceName;
          in
            if matches != null
            then builtins.head matches
            else null;
          readOnly = true;
        };
        sleep-on-idle = mkOption {
          type = types.anything;
        };
        oci-containers = mkOption {
          type = types.anything;
          default = {};
        };
        cloudflared = {
          enable = mkOption {
            type = types.bool;
            default = cfg.cloudflared.tunnel-id != null;
            readOnly = true;
          };
          tunnel-id = mkOption {
            type = types.nullOr types.singleLineStr;
            default = null;
          };
          unix-socket = mkOption {
            type = types.strMatching "^\/run\/.+\/.+$";
            default = "/run/proxy-compose/${name}/${name}.sock";
          };
        };
        hostName = mkOption {
          type = types.singleLineStr;
        };
        caddy = {
          extraConfig = mkOption {
            type = types.lines;
            default = '''';
          };
          add-encode = mkOption {
            type = types.bool;
            default = true;
          };
          add-handle-reverse-proxy = mkOption {
            type = types.bool;
            default = config.myOpt.sleep-on-idle.${cfg.serviceName}.endpoints ? default;
          };
        };
        default-caddy-origin-socket-address = mkOption {
          type = types.nullOr (types.strMatching "^[^\/].+$");
          default = let
            inherit (config.myOpt.sleep-on-idle.${name}) endpoints;
          in (
            if endpoints ? default
            then to-caddy-socket-address endpoints.default.proxy.socket-address
            else null
          );
          readOnly = true;
        };
      };
    }));
  };

  config = {
    assertions = flatten (mapAttrsToList (name: cfg: let
        inherit (cfg.caddy) add-handle-reverse-proxy;
        inherit (config.myOpt.sleep-on-idle.${name}) endpoints;
        inherit (cfg) localMode cloudflared;
      in [
        {
          assertion = !(add-handle-reverse-proxy && !(endpoints ? default));
        }
        {
          assertion = !(localMode.enable && cloudflared.enable);
        }
      ])
      config.myOpt.proxy-compose);

    systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: [
        "d ${builtins.dirOf cfg.cloudflared.unix-socket} 777 - - - -"
      ])
      enabled-cloudflared-proxy-compose);

    myOpt.cloudflared = mkMerge (
      mapAttrsToList (name: cfg: {
        ${cfg.cloudflared.tunnel-id} = {
          ingress.${cfg.hostName} = "unix:${cfg.cloudflared.unix-socket}";
        };
      })
      enabled-cloudflared-proxy-compose
    );

    services.caddy = mkMerge (mapAttrsToList (
        _: cfg: let
          inherit (cfg) localMode caddy cloudflared hostName default-caddy-origin-socket-address;
          inherit (cfg.caddy) add-handle-reverse-proxy add-encode;
          extraConfig = ''
            ${caddy.extraConfig}
            ${
              if add-handle-reverse-proxy
              then ''
                handle {
                  reverse_proxy ${default-caddy-origin-socket-address}
                }
              ''
              else ''''
            }
            ${
              if (add-encode && !localMode.enable)
              then ''
                encode
              ''
              else ''''
            }
          '';
        in {
          enable = true;
          openFirewall = mkIf (!localMode.enable && !cloudflared.enable) true;
          extraConfig = mkIf (cloudflared.enable) ''
            http:// {
              bind "unix/${cloudflared.unix-socket}|0777"
              ${extraConfig}
            }
          '';
          virtualHosts = mkIf (!cloudflared.enable) {
            ${
              if localMode.enable
              then "http://${localMode.ip-socket}"
              else hostName
            } = {
              inherit extraConfig;
            };
          };
        }
      )
      config.myOpt.proxy-compose);

    myOpt.sleep-on-idle =
      mapAttrs' (_: cfg: (nameValuePair cfg.serviceName cfg.sleep-on-idle))
      config.myOpt.proxy-compose;

    containers =
      mapAttrs' (_: cfg: (nameValuePair cfg.containerName {
        ephemeral = true;
        autoStart = false;
        config.nixpkgs.pkgs = pkgs;
      }))
      (filterAttrs (_: cfg: cfg.containerName != null) config.myOpt.proxy-compose);

    # virtualisation.oci-containers.containers = concatMapAttrs (name1: cfg1:
    #   (mapAttrs' (name2: cfg2: (nameValuePair name2 (mkMerge [
    #       cfg2
    #       {
    #         autoStart = false;
    #         serviceName = name2;
    #       }
    #     ])))
    #     cfg1.oci-containers)
    #   config.myOpt.proxy-compose);

    # systemd.services = concatMapAttrs (name1: cfg1:
    #   (mapAttrs' (name2: cfg2: (
    #       nameValuePair name2 {
    #         unitConfig = {
    #           StartLimitIntervalSec = mkDefault "10";
    #           StartLimitBurst = mkDefault "5";
    #         };
    #         serviceConfig = {
    #           RemainAfterExit = mkDefault true;
    #           Restart = mkDefault "on-failure";
    #           RestartMaxDelaySec = mkDefault "5min";
    #           RestartSteps = mkDefault "10";
    #           RestartSec = mkDefault "1";
    #         };
    #       }
    #     ))
    #     cfg1.oci-containers)
    #   config.myOpt.proxy-compose);
  };
}
