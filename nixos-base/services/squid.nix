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
      visible_hostname squid-${name}
      http_port [${cfg.host}]:${toString cfg.port}
      pid_filename none
      pinger_enable off
      umask 0077
      cache_log stdio:/var/log/squid-${name}/cache.log
      access_log stdio:/var/log/squid-${name}/access.log
      cache_store_log stdio:/var/log/squid-${name}/store.log

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
    else pkgs.writeText "squid-${name}.conf" text) enabled;
in {
  imports = [
    ./systemd-socket-proxyd.nix
    ./sleep-on-idle
  ];

  options.myOpt.squid = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...}: {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "squid@${name}";
          readOnly = true;
        };
        package = mkOption {
          type = types.package;
        };
        host = mkOption {
          type = types.singleLineStr;
          default = "::1";
          readOnly = true;
        };
        port = mkOption {
          type = types.port;
        };
        extraConfig = mkOption {
          type = types.lines;
        };
        validateConfig = mkOption {
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
        proxy = {
          serviceName = mkOption {
            type = types.singleLineStr;
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
    assertions =
      mapAttrsToList (name: _: {
        assertion = builtins.match "[A-Za-z0-9_][A-Za-z0-9_-]{0,24}" name != null;
        message = "myOpt.squid instance names must contain 1-25 letters, digits, underscores or hyphens and must not start with a hyphen.";
      }) enabled
      ++ [
        {
          assertion = let
            listeners = mapAttrsToList (_: cfg: "${cfg.host}:${toString cfg.port}") enabled;
          in length (unique listeners) == length listeners;
          message = "myOpt.squid instances must have distinct listener addresses/ports.";
        }
        {
          assertion = let
            names = mapAttrsToList (_: cfg: cfg.proxy.serviceName) enabled;
          in length (unique names) == length names;
          message = "myOpt.squid proxy service names must be unique.";
        }
        {
          assertion = all (cfg: !(elem cfg.proxy.serviceName (mapAttrsToList (_: cfg: cfg.serviceName) enabled))) (attrValues enabled);
          message = "myOpt.squid proxy service names must not collide with native Squid instance units.";
        }
        {
          assertion = let
            paths = mapAttrsToList (_: cfg: cfg.proxy.unix-socket) enabled;
          in
            length (unique paths) == length paths
            && all (a: all (b: a == b || !(hasPrefix "${a}/" b || hasPrefix "${b}/" a)) paths) paths;
          message = "myOpt.squid proxy socket paths must not overlap.";
        }
        {
          assertion = all (cfg:
            all (name: !hasPrefix "/run/squid-${name}/" cfg.proxy.unix-socket && cfg.proxy.unix-socket != "/run/squid-${name}") (attrNames enabled)) (attrValues enabled);
          message = "myOpt.squid proxy sockets must be outside Squid's per-instance runtime directories.";
        }
      ];

    environment.etc = mapAttrs' (name: _: nameValuePair "squid/${name}.conf" {
      source = configFiles.${name};
    }) enabled;

    systemd.services = mkMerge [
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
      (mapAttrs' (name: cfg: nameValuePair cfg.serviceName {
        overrideStrategy = "asDropin";
        restartTriggers = [configFiles.${name} cfg.package];
        environment = {
          SQUID_BINARY = "${cfg.package}/bin/squid";
          SQUID_CONFIG = "/etc/squid/${name}.conf";
        };
        serviceConfig = {
          CapabilityBoundingSet = optionalString (cfg.port < 1024) "CAP_NET_BIND_SERVICE";
          AmbientCapabilities = optionalString (cfg.port < 1024) "CAP_NET_BIND_SERVICE";
          RemainAfterExit = mkForce false;
        };
      }) enabled)
    ];

    myOpt.systemd-socket-proxyd = mapAttrs (name: cfg: {
      origin = {
        serviceName = cfg.serviceName;
        host = cfg.host;
        port = cfg.port;
      };
      proxy = {
        inherit (cfg.proxy) serviceName;
        ip-socket = cfg.proxy.unix-socket;
      };
    }) enabled;

    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.sleep-on-idle.id}.set-cgroup-parent = {
          systemd-services = [cfg.proxy.serviceName cfg.serviceName];
          nixos-containers = [];
          oci-containers = [];
        };
      })
      (filterAttrs (_: cfg: cfg.sleep-on-idle.enable) enabled));
  };
}
