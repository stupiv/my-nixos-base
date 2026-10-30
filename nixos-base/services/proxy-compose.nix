{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  inherit (pkgs) myLib;
  outerCfg = config;
  enabled = filterAttrs (name: cfg: cfg.enable) outerCfg.myOpt.proxy-compose;
  enabled-cloudflared = filterAttrs (name: cfg: cfg.cloudflared.enable) enabled;
  to-caddy-ip-socket = ip-socket: (
    if (hasPrefix "/" ip-socket)
    then "unix/${ip-socket}"
    else ip-socket
  );
in {
  options.myOpt.proxy-compose = mkOption {
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
          sleep-on-idle = mkOption {
            type = types.anything;
          };
        };
        hostname = mkOption {
          type = types.singleLineStr;
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
        cloudflared = {
          enable = mkOption {
            type = types.bool;
            default = cfg.modules.cloudflared != {};
            readOnly = true;
          };
          unix-socket = mkOption {
            type = types.strMatching "^\/run\/.+\/.+$";
            default = "/run/proxy-compose/${name}/${name}.sock";
          };
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
            default = true;
          };
          request_body.max_size = mkOption {
            type = types.str;
            default = "16MiB";
          };
        };
        default-caddy-origin-ip-socket = mkOption {
          type = types.strMatching "^[^\/].+$";
          default = to-caddy-ip-socket endpoints.default.proxy.ip-socket;
          readOnly = true;
        };
      };
    }));
  };

  config = {
    assertions = flatten (mapAttrsToList (name: cfg: let
        inherit (cfg) localMode cloudflared;
      in [
        {
          assertion = !(localMode.enable && cloudflared.enable);
        }
      ])
      enabled);

    myOpt.sleep-on-idle =
      mapAttrs' (name: cfg: (nameValuePair name (mkMerge [
        cfg.modules.sleep-on-idle
        {
          enable = true;
        }
      ])))
      enabled;

    systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: [
        "d ${builtins.dirOf cfg.cloudflared.unix-socket} 711 caddy caddy - -"
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
  };
}
