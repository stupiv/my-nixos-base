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
        sleep-on-idle = {
          enable = mkOption {
            type = types.bool;
          };
          id = mkOption {
            type = types.singleLineStr;
          };
        };
        egress-restriction = {
          enable = mkOption {
            type = types.bool;
            description = "Whether to use the custom Squid egress-restriction configuration.";
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
        fqdn-list = mkOption {
          type = types.listOf (types.strMatching "^\\.?([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\\.)+[A-Za-z]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$");
          default = [];
          description = ''
            FQDNs Squid may connect to. An entry without a leading dot matches
            that exact name; prefix with a dot to also match its subdomains.
            An empty list denies all proxy destinations.
          '';
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
              }
              (mkIf cfg.egress-restriction.enable {
                configText = mkForce ''
                  acl my_squid_connect method CONNECT
                  acl my_squid_https_port port 443
                  acl my_squid_non_public_dst dst 0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 198.18.0.0/15 224.0.0.0/4 240.0.0.0/4
                  acl my_squid_non_public_dst dst ::/128 ::1/128 fc00::/7 fe80::/10 ff00::/8
                  ${optionalString (cfg.fqdn-list != []) ''
                    acl my_squid_allowed_fqdns dstdomain -n ${concatStringsSep " " cfg.fqdn-list}
                  ''}

                  http_access deny to_localhost
                  http_access deny my_squid_non_public_dst
                  http_access deny !my_squid_connect
                  http_access deny my_squid_connect !my_squid_https_port
                  ${optionalString (cfg.fqdn-list != []) ''
                    http_access allow my_squid_connect my_squid_https_port my_squid_allowed_fqdns
                  ''}
                  http_access deny all

                  cache deny all
                  cache_log stdio:/var/log/squid/cache.log
                  access_log stdio:/var/log/squid/access.log
                  pid_filename ${config.systemd.services.squid.serviceConfig.PIDFile}
                  cache_effective_user squid squid
                  http_port ${optionalString (config.services.squid.proxyAddress != null) "${config.services.squid.proxyAddress}:"}${toString config.services.squid.proxyPort}
                  coredump_dir /var/cache/squid
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
