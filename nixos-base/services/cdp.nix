{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.cdp;
in {
  options.myOpt.cdp = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "cdp-${name}";
        };
        package = mkOption {
          type = types.package;
        };
        host = mkOption {
          type = types.singleLineStr;
          default = "::1";
        };
        port = mkOption {
          type = types.port;
        };
        StateDirectory = mkOption {
          type = types.addCheck (types.strMatching "^[A-Za-z0-9_][A-Za-z0-9_.-]*(/[A-Za-z0-9_][A-Za-z0-9_.-]*)*$") (s: s != "private" && !(hasPrefix "private/" s));
        };
        RuntimeDirectory = mkOption {
          type = types.strMatching "^[A-Za-z0-9_][A-Za-z0-9_.-]*(/[A-Za-z0-9_][A-Za-z0-9_.-]*)*$";
          default = "cdp-${name}";
        };
        netns-id = mkOption {
          type = types.nullOr types.singleLineStr;
        };
        sleep-on-idle-id = mkOption {
          type = types.nullOr types.singleLineStr;
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    systemd.services = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.serviceName} = {
          environment = {
            HOME = "%S/${cfg.StateDirectory}";
            XDG_RUNTIME_DIR = "%t/${cfg.RuntimeDirectory}";
          };
          serviceConfig = {
            Type = "exec";
            ExecStart = "${getExe cfg.package} --headless=new --remote-debugging-port=${toString cfg.port} --remote-debugging-address=${cfg.host} --user-data-dir='$HOME/cdp-debug' --no-first-run --no-default-browser-check";
            Restart = "on-failure";
            KillMode = "mixed";
            DynamicUser = true;
            WorkingDirectory = "%S/${cfg.StateDirectory}";
            StateDirectory = cfg.StateDirectory;
            StateDirectoryMode = "0700";
            RuntimeDirectory = cfg.RuntimeDirectory;
            RuntimeDirectoryMode = "0700";
            UMask = "0077";
            NoNewPrivileges = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            CapabilityBoundingSet = "";
            LimitCORE = 0;
          };
        };
      })
      enabled);

    myOpt.netns = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.netns-id}.set-network-namespace.systemd-services = [cfg.serviceName];
      })
      (filterAttrs (_: cfg: cfg.netns-id != null) enabled));

    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.sleep-on-idle-id}.set-cgroup-parent.systemd-services = [cfg.serviceName];
      })
      (filterAttrs (_: cfg: cfg.sleep-on-idle-id != null) enabled));
  };
}
