{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.caddy;
  to-caddy-ip-socket = ip-socket: (
    if (hasPrefix "/" ip-socket)
    then "unix/${ip-socket}"
    else ip-socket
  );
in {
  options.myOpt.caddy = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        local = {
          enable = mkOption {
            type = types.bool;
            default = cfg.local.unix.enable || cfg.local.tcp.enable;
            readOnly = true;
          };
          unix = {
            enable = mkOption {
              type = types.bool;
              default = cfg.local.unix.socket != null;
              readOnly = true;
            };
            socket = mkOption {
              type = types.nullOr (types.strMatching "^/run/.*\.sock$");
              default = null;
            };
            mode = mkOption {
              type = types.singleLineStr;
              default = "0777";
            };
          };
          tcp = {
            enable = mkOption {
              type = types.bool;
              default = cfg.local.tcp.port != null;
              readOnly = true;
            };
            host = mkOption {
              type = types.singleLineStr;
              default = "::1";
            };
            port = mkOption {
              type = types.nullOr types.port;
              default = null;
            };
            socket = mkOption {
              type = types.singleLineStr;
              default = pkgs.myLib.bracketIpv6 "${cfg.local.tcp.host}:${toString cfg.local.tcp.port}";
            };
          };
        };
        hostname = mkOption {
          type = types.singleLineStr;
        };
        mk-reverse-proxy-extraConfig = mkOption {
          type = types.anything;
          default = cfg: '''';
        };
        reverse-proxy-extraConfig = mkOption {
          type = types.lines;
          default = cfg.mk-reverse-proxy-extraConfig cfg;
          readOnly = true;
        };
        mk-extraConfig = mkOption {
          type = types.anything;
          default = cfg: '''';
        };
        extraConfig = mkOption {
          type = types.lines;
          default = cfg.mk-extraConfig cfg;
          readOnly = true;
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
          type = types.singleLineStr;
          default = "16MiB";
        };
        caddy-origin-socket = mkOption {
          type = types.strMatching "^unix//run/.*\.sock$";
          default = to-caddy-ip-socket cfg.unix-socket;
          readOnly = true;
        };
        sleep-on-idle-id = mkOption {
          type = types.singleLineStr;
        };
        sleep-on-idle-cfg = mkOption {
          type = types.anything;
          default = outerCfg.myOpt.sleep-on-idle.${cfg.sleep-on-idle-id};
          readOnly = true;
        };
        unix-socket = mkOption {
          type = types.strMatching "^/run/.*\.sock$";
          default = cfg.sleep-on-idle-cfg.endpoints.default.proxy.ip-socket;
          readOnly = true;
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: [
        "d '${builtins.dirOf cfg.local.unix.socket}' 0711 caddy caddy - -"
      ])
      (filterAttrs (_: cfg: cfg.local.unix.enable) enabled));

    services.caddy = mkMerge ([
        {
          enable = true;
        }
      ]
      ++ (mapAttrsToList (
          _: cfg: let
            inherit (cfg) local hostname add-handle-reverse-proxy add-encode request_body reverse-proxy-extraConfig caddy-origin-socket;
            extraConfig = ''
              ${cfg.extraConfig}
              request_body {
                max_size ${request_body.max_size}
              }
              ${
                if add-handle-reverse-proxy
                then ''
                  handle {
                    reverse_proxy ${caddy-origin-socket} {
                      ${reverse-proxy-extraConfig}
                    }
                  }
                ''
                else ''''
              }
              ${
                if (add-encode && !local.enable)
                then ''
                  encode
                ''
                else ''''
              }
            '';
          in {
            openFirewall = mkIf (!local.enable) true;
            extraConfig = mkIf (local.unix.enable) ''
              http:// {
                bind "unix/${local.unix.socket}|${local.unix.mode}"
                ${extraConfig}
              }
            '';
            virtualHosts = mkMerge [
              (optionalAttrs (local.tcp.enable) {
                "http://${local.tcp.socket}" = {
                  inherit extraConfig;
                };
              })
              (optionalAttrs (!local.enable) {
                ${hostname} = {
                  inherit extraConfig;
                };
              })
            ];
          }
        )
        enabled));
  };
}
