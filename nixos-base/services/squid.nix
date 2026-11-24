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
      cache_dir ufs /var/lib/${cfg.StateDirectory} 100 16 256
      pid_filename /run/${cfg.RuntimeDirectory}/squid.pid

      http_port [${cfg.tcp-to-unix.cfg.origin.host}]:${toString cfg.tcp-to-unix.cfg.origin.port}
      ${optionalString cfg.egress-restriction.enable ''
        acl my_squid_connect method CONNECT
        acl my_squid_https_port port 443
        acl my_squid_allowed_fqdns dstdomain -n ${concatStringsSep " " cfg.egress-restriction.fqdns}
        http_access deny !my_squid_connect
        http_access deny my_squid_connect !my_squid_https_port
        http_access deny my_squid_connect my_squid_https_port !my_squid_allowed_fqdns
        http_access allow my_squid_connect my_squid_https_port my_squid_allowed_fqdns
      ''}
      ${optionalString (!cfg.egress-restriction.enable) ''
        http_access allow all
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
        ${cfg.package}/bin/squid -k parse -f "$out"
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
        StateDirectory = mkOption {
          type = types.addCheck (types.strMatching "^[A-Za-z0-9_][A-Za-z0-9_.-]*(/[A-Za-z0-9_][A-Za-z0-9_.-]*)*$") (s: s != "private" && !(hasPrefix "private/" s));
          default = "squid-${name}";
        };
        RuntimeDirectory = mkOption {
          type = types.strMatching "^[A-Za-z0-9_][A-Za-z0-9_.-]*(/[A-Za-z0-9_][A-Za-z0-9_.-]*)*$";
          default = "squid-${name}";
        };
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "squid-${name}";
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
            type = types.listOf (types.singleLineStr);
            default = [];
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
            readOnly = true;
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
            readOnly = true;
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
    assertions = concatLists (mapAttrsToList (name: cfg: [
      {
        assertion = !cfg.egress-restriction.enable || cfg.egress-restriction.fqdns != [];
        message = "myOpt.squid.${name}.egress-restriction.fqdns must be non-empty when myOpt.squid.${name}.egress-restriction.enable is true";
      }
    ]) enabled);
    systemd.services = mkMerge (
      mapAttrsToList (name: cfg: {
        ${cfg.serviceName} = {
          after = ["network-online.target" "nss-lookup.target"];
          wants = ["network-online.target"];
          restartTriggers = [configFiles.${name} cfg.package];
          environment.TMPDIR = "%t/${cfg.RuntimeDirectory}";
          serviceConfig = {
            Type = "notify";
            NotifyAccess = "main";
            DynamicUser = true;
            User = "squid-${name}";
            Group = "squid-${name}";
            StateDirectory = cfg.StateDirectory;
            StateDirectoryMode = "0700";
            RuntimeDirectory = cfg.RuntimeDirectory;
            RuntimeDirectoryMode = "0700";
            LogsDirectory = "squid-${name}";
            LogsDirectoryMode = "0700";
            WorkingDirectory = "%S/${cfg.StateDirectory}";
            ExecStartPre = "${cfg.package}/bin/squid --foreground -z -f ${configFiles.${name}}";
            ExecStart = "${cfg.package}/bin/squid --foreground -YCs -f ${configFiles.${name}}";
            KillMode = "mixed";
            Restart = "on-failure";
            NoNewPrivileges = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ProtectControlGroups = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            CapabilityBoundingSet = "";
            LimitCORE = 0;
            UMask = "0077";
          };
        };
      }) enabled
      ++ mapAttrsToList (_: cfg: (genAttrs cfg.set-env-vars.systemd-services (_: {
          inherit (cfg) environment;
        })))
        enabled);
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
