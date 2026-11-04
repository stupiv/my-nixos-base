{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.squid;
in {
  options.myOpt.squid = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        egress-restriction = {
          enable = mkOption {
            type = types.bool;
          };
          fqdns = mkOption {
            type = types.listOf (types.strMatching "^\\.?([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\\.)+[A-Za-z]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$");
          };
        };
        sleep-on-idle = {
          enable = mkOption {
            type = types.bool;
          };
          id = mkOption {
            type = types.singleLineStr;
          };
        };
        modules.services.squid = mkOption {
          type = types.submodule ({...}: {
            freeformType = types.anything;
            options = {
              package = mkOption {
                type = types.anything;
              };
              proxyPort = mkOption {
                type = types.anything;
              };
              proxyAddress = mkOption {
                type = types.anything;
                default = "::1";
              };
            };
          });
        };
        container = mkOption {
          type = types.submodule ({...}: {
            freeformType = types.anything;
            options = {
              name = mkOption {
                type = types.singleLineStr;
              };
            };
          });
        };
        cacheDir = mkOption {
          type = types.singleLineStr;
        };
        logDir = mkOption {
          type = types.singleLineStr;
        };
        proxy = {
          serviceName = mkOption {
            types = types.singleLineStr;
            default = name;
          };
          unix-socket = mkOption {
            type = types.strMatching "^/run/[^/]+/.*[^/]$";
          };
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    systemd.tmpfiles.rules = flatten (mapAttrsToList (name: cfg: [
        "d '${cfg.logDir}' - - - - -"
        "d '${cfg.cacheDir}' - - - - -"
      ])
      enabled);
    containers = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.container.name} = {
          ephemeral = true;
          autoStart = false;
          privateNetwork = false;
          privateUsers = "pick";
          extraFlags = [
            "--bind=${cfg.logDir}:/var/log/squid:idmap"
            "--bind=${cfg.cacheDir}:/var/cache/squid:idmap"
          ];
          config = {config, ...}: {
            nixpkgs.pkgs = pkgs;
            systemd.tmpfiles.rules = [
              "d '${cfg.logDir}' 0700 squid squid - -"
              "d '${cfg.cacheDir}' 0700 squid squid - -"
            ];
            services.squid = mkMerge [
              cfg.modules.services.squid
              {
                enable = true;
                configFile = null;
              }
              (mkIf cfg.egress-restristion.enable {
                extraConfig = mkBefore ''
                  acl my_squid_connect method CONNECT
                  acl my_squid_https_port port 443
                  ${optionalString (cfg.egress-restristion.fqdns != []) ''
                    acl my_squid_allowed_fqdns dstdomain -n ${concatStringsSep " " cfg.egress-restristion.fqdns}
                  ''}

                  http_access deny !my_squid_connect
                  http_access deny my_squid_connect !my_squid_https_port
                  ${optionalString (cfg.egress-restristion.fqdns != []) ''
                    http_access deny my_squid_connect my_squid_https_port !my_squid_allowed_fqdns
                    http_access allow my_squid_connect my_squid_https_port my_squid_allowed_fqdns
                  ''}
                '';
              })
            ];
          };
        };
      })
      enabled);
    myOpt.systemd-socket-proxyd = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.systemd-socket-proxyd-id} = {
          origin = {
            serviceName = "container@${cfg.container.name}";
            host = cfg.modules.services.squid.proxyAddress;
            port = cfg.modules.services.squid.proxyPort;
          };
          proxy = {
            inherit (cfg.proxy) serviceName;
            ip-socket = cfg.proxy.unixSocket;
          };
        };
      })
      enabled);
    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.sleep-on-idle.id} = {
          set-cgroup-parent = {
            systemd-services = [cfg.proxy.serviceName];
            nixos-containers = [cfg.container.name];
          };
        };
      })
      (filterAttrs (_: cfg: cfg.sleep-on-idle.enable) enabled));
  };
}
