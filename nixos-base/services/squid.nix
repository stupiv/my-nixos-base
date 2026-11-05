{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.squid;
  configFiles = mapAttrs (name: cfg: let
    text = ''
      cache_log stdio:/var/log/squid-${name}/cache.log
      access_log stdio:/var/log/squid-${name}/access.log
      cache_store_log stdio:/var/log/squid-${name}/store.log

      http_port [${cfg.tcp-to-unix.cfg.origin.host}]:${toString cfg.tcp-to-unix.cfg.origin.port}
      ${optionalString cfg.egress-restriction.enable ''
        acl my_squid_connect method CONNECT
        acl my_squid_https_port port 443
        ${optionalString (cfg.egress-restriction.fqdns != []) ''
          acl my_squid_allowed_fqdns dstdomain -n ${concatStringsSep " " cfg.egress-restriction.fqdns}
        ''}
        http_access deny !my_squid_connect
        http_access deny my_squid_connect !my_squid_https_port
        ${optionalString (cfg.egress-restriction.fqdns != []) ''
          http_access deny my_squid_connect my_squid_https_port !my_squid_allowed_fqdns
          http_access allow my_squid_connect my_squid_https_port my_squid_allowed_fqdns
        ''}
      ''}
      ${cfg.extraConfig}
    '';
  in
    if cfg.validateConfig
    then
      pkgs.runCommand "squid-${name}.conf" {
        inherit text;
        passAsFile = ["text"];
        preferLocalBuild = true;
        allowSubstitutes = false;
      } ''
        cp "$textPath" "$out"
        ${cfg.package}/bin/squid -n ${escapeShellArg name} -k parse -f "$out"
      ''
    else pkgs.writeText "squid-${name}.conf" text)
  enabled;
in {
  imports = [
    ./systemd-socket-proxyd.nix
    ./sleep-on-idle
  ];

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
        sleep-on-idle-id = mkOption {
          type = types.singleLineStr;
        };
        netns-id = mkOption {
          type = types.singleLineStr;
        };
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "squid@${name}";
          readOnly = true;
        };
        package = mkOption {
          type = types.package;
        };
        extraConfig = mkOption {
          type = types.lines;
          default = '''';
        };
        validateConfig = mkOption {
          type = types.bool;
          default = true;
        };
        egress-restriction = {
          enable = mkOption {
            type = types.bool;
            default = true;
          };
          fqdns = mkOption {
            type = types.listOf (types.strMatching "^\\.?([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\\.)+[A-Za-z]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$");
          };
        };
        tcp-to-unix = {
          id = mkOption {
            type = types.singleLineStr;
            default = "${name}-tcp-to-unix";
          };
          cfg = mkOption {
            type = types.anything;
            default = outerCfg.myOpt.systemd-socket-proxyd.${cfg.tcp-to-unix.id};
          };
          origin = {
            port = mkOption {
              type = types.port;
            };
          };
        };
        unix-socket = mkOption {
          type = types.strMatching "^/run/[^/]+/.*[^/]$";
          default = "/run/squid/${name}.sock";
        };
        unix-to-tcp = {
          id = mkOption {
            type = types.singleLineStr;
            default = "${name}-unix-to-tcp";
          };
          cfg = mkOption {
            type = types.anything;
            default = outerCfg.myOpt.systemd-socket-proxyd.${cfg.unix-to-tcp.id};
          };
          proxy = {
            port = mkOption {
              type = types.port;
            };
          };
        };
        environment = {
          HTTP_PROXY = mkOption {
            type = types.strMatching "^http.+[^/]$";
            default = "http://${cfg.unix-to-tcp.cfg.proxy.ip-socket}";
            readOnly = true;
          };
          HTTPS_PROXY = mkOption {
            type = types.strMatching "^http.+[^/]$";
            default = cfg.environment.HTTP_PROXY;
            readOnly = true;
          };
          NO_PROXY = mkOption {
            type = types.singleLineStr;
            default = "localhost,127.0.0.1,::1";
            readOnly = true;
          };
        };
        set-env-vars = mkOption {
          type = types.anything;
          default = outerCfg.myOpt.netns.${cfg.netns-id}.set-network-namespace;
          readOnly = true;
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    environment.etc = mapAttrs' (name: _:
      nameValuePair "squid/${name}.conf" {
        source = configFiles.${name};
      })
    enabled;

    systemd.services = mkMerge ([
        {
          "squid@" = {
            after = ["network.target" "nss-lookup.target"];
            unitConfig.ConditionPathExists = "/etc/squid/%i.conf";
            environment.TMPDIR = "/run/squid-%i";
            serviceConfig = {
              Type = "notify";
              NotifyAccess = "main";
              DynamicUser = true;
              User = "squid-%i";
              Group = "squid-%i";
              RuntimeDirectory = "squid-%i";
              RuntimeDirectoryMode = "0700";
              CacheDirectory = "squid-%i";
              CacheDirectoryMode = "0700";
              LogsDirectory = "squid-%i";
              LogsDirectoryMode = "0700";
              WorkingDirectory = "/var/cache/squid-%i";
              NoExecPaths = ["/var/cache/squid-%i" "/var/log/squid-%i" "/run/squid-%i"];
              ExecStartPre = "${pkgs.coreutils}/bin/env -- \${SQUID_BINARY} -N -n %i -z -f \${SQUID_CONFIG}";
              ExecStart = "${pkgs.coreutils}/bin/env -- \${SQUID_BINARY} -N -C -n %i -f \${SQUID_CONFIG}";
              ExecReload = [
                "${pkgs.coreutils}/bin/env -- \${SQUID_BINARY} -n %i -k parse -f \${SQUID_CONFIG}"
                "${pkgs.coreutils}/bin/kill -HUP $MAINPID"
              ];
              KillMode = "mixed";
              Restart = "on-failure";
              NoNewPrivileges = true;
              PrivateTmp = true;
              PrivateDevices = true;
              PrivateIPC = true;
              ProtectSystem = "strict";
              ProtectHome = true;
              ProtectClock = true;
              ProtectControlGroups = true;
              ProtectHostname = true;
              ProtectKernelLogs = true;
              ProtectKernelModules = true;
              ProtectKernelTunables = true;
              ProtectProc = "invisible";
              CapabilityBoundingSet = "";
              AmbientCapabilities = "";
              KeyringMode = "private";
              LimitCORE = 0;
              LockPersonality = true;
              MemoryDenyWriteExecute = true;
              RemoveIPC = true;
              RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK"];
              RestrictNamespaces = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              SystemCallArchitectures = "native";
              SystemCallFilter = ["@system-service"];
              SystemCallErrorNumber = "EPERM";
              UMask = "0077";
            };
          };
        }
        (mapAttrs' (name: cfg:
          nameValuePair cfg.serviceName {
            overrideStrategy = "asDropin";
            restartTriggers = [configFiles.${name} cfg.package];
            environment = {
              SQUID_BINARY = "${cfg.package}/bin/squid";
              SQUID_CONFIG = "/etc/squid/${name}.conf";
            };
          })
        enabled)
      ]
      ++ (mapAttrsToList (_: cfg: (genAttrs cfg.set-env-vars.systemd-services (_: {
          inherit (cfg) environment;
        })))
        enabled));
    virtualisation.oci-containers.containers = mkMerge (
      mapAttrsToList (_: cfg: (genAttrs cfg.set-env-vars.oci-containers (_: {
        inherit (cfg) environment;
      })))
      enabled
    );
    containers = mkMerge (
      mapAttrsToList (_: cfg: (genAttrs cfg.set-env-vars.nixos-containers (_: {
        config.environment.variables = cfg.environment;
      })))
      enabled
    );

    myOpt.systemd-socket-proxyd = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.tcp-to-unix.id} = {
          origin = {
            inherit (cfg) serviceName;
            inherit (cfg.tcp-to-unix.origin) port;
          };
          proxy.ip-socket = cfg.unix-socket;
        };
        ${cfg.unix-to-tcp.id} = {
          inherit (cfg.unix-to-tcp) proxy;
          origin = {
            inherit (cfg.tcp-to-unix.cfg.proxy) serviceName ip-socket;
          };
        };
      })
      enabled);

    myOpt.netns = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.netns-id}.set-network-namespace = {
          systemd-services = [
            cfg.unix-to-tcp.cfg.proxy.serviceName
          ];
        };
      })
      enabled);

    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.sleep-on-idle-id}.set-cgroup-parent = {
          systemd-services = [
            cfg.serviceName
            cfg.tcp-to-unix.cfg.proxy.serviceName
            cfg.unix-to-tcp.cfg.proxy.serviceName
          ];
        };
      })
      enabled);
  };
}
