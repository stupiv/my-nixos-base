{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  inherit (pkgs) myLib;
  outerCfg = config;
  enabled = filterAttrs (name: cfg: cfg.enable) outerCfg.myOpt.proxy-compose-v2;
  enabled-cloudflared = filterAttrs (name: cfg: cfg.cloudflared.enable) enabled;
  to-caddy-ip-socket = ip-socket: (
    if (hasPrefix "/" ip-socket)
    then "unix/${ip-socket}"
    else ip-socket
  );
in {
  options.myOpt.proxy-compose-v2 = mkOption {
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
          cloudflared = mkOption {
            type = types.anything;
            default = {};
          };
        };
        localMode = {
          enable = mkOption {
            type = types.bool;
            default = false;
          };
          host = mkOption {
            type = types.singleLineStr;
            default = "localhost";
            # default = "::1";
          };
          port = mkOption {
            type = types.port;
          };
          ip-socket = mkOption {
            type = types.singleLineStr;
            default = "${cfg.localMode.host}:${toString cfg.localMode.port}";
            # default = myLib.bracketIpv6 "${cfg.localMode.host}:${toString cfg.localMode.port}";
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
        sleep-on-idle-v2 = mkOption {
          type = types.anything;
        };
        oci-containers = mkOption {
          type = types.anything;
          default = {};
        };
        cloudflared = {
          enable = mkOption {
            type = types.bool;
            default = cfg.modules.cloudflared != {};
            readOnly = true;
          };
          unix-socket = mkOption {
            type = types.strMatching "^\/run\/.+\/.+$";
            default = "/run/proxy-compose-v2/${name}/${name}.sock";
          };
        };
        hostname = mkOption {
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
            default = config.myOpt.sleep-on-idle-v2.${cfg.serviceName}.endpoints ? default;
          };
          request_body.max_size = mkOption {
            type = types.str;
            default = "16MiB";
          };
        };
        default-caddy-origin-ip-socket = mkOption {
          type = types.nullOr (types.strMatching "^[^\/].+$");
          default = let
            inherit (config.myOpt.sleep-on-idle-v2.${name}) endpoints;
          in (
            if endpoints ? default
            then to-caddy-ip-socket endpoints.default.proxy.ip-socket
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
        inherit (config.myOpt.sleep-on-idle-v2.${name}) endpoints;
        inherit (cfg) localMode cloudflared;
      in [
        {
          assertion = !(add-handle-reverse-proxy && !(endpoints ? default));
        }
        {
          assertion = !(localMode.enable && cloudflared.enable);
        }
      ])
      enabled);

    systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: [
        "d ${builtins.dirOf cfg.cloudflared.unix-socket} 777 - - - -"
      ])
      enabled-cloudflared);

    myOpt.cloudflared = mkMerge (
      mapAttrsToList (name: cfg: {
        ${cfg.modules.cloudflared.tunnel-id} = mkMerge [
          cfg.modules.cloudflared
          {
            enable = true;
            tunnelCfg = {
              ingress.${cfg.hostname} = "unix:${cfg.cloudflared.unix-socket}";
            };
          }
        ];
      })
      enabled-cloudflared
    );

    services.caddy = mkMerge (mapAttrsToList (
        _: cfg: let
          inherit (cfg) localMode caddy cloudflared hostname default-caddy-origin-ip-socket;
          inherit (cfg.caddy) add-handle-reverse-proxy add-encode request_body;
          extraConfig = ''
            ${caddy.extraConfig}
            request_body {
              max_size ${request_body.max_size}
            }
            ${
              if add-handle-reverse-proxy
              then ''
                handle {
                  reverse_proxy ${default-caddy-origin-ip-socket}
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
              else hostname
            } = {
              inherit extraConfig;
            };
          };
        }
      )
      enabled);

    myOpt.sleep-on-idle-v2 =
      mapAttrs' (_: cfg: (nameValuePair cfg.serviceName cfg.sleep-on-idle-v2))
      enabled;

    containers =
      mapAttrs' (_: cfg: (nameValuePair cfg.containerName {
        ephemeral = mkDefault true;
        config.nixpkgs.pkgs = pkgs;
      }))
      (filterAttrs (_: cfg: cfg.containerName != null) enabled);
  };
}
