{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.camofox-browser;
  inherit (inputs.camoufox-nix.packages.${pkgs.stdenv.hostPlatform.system}) camoufox-bin;
in {
  options.myOpt.camofox-browser = mkOption {
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
          default = "camofox-browser-${name}";
        };
        camoufox.package = mkOption {
          type = types.package;
          default = camoufox-bin;
        };
        package = mkOption {
          type = types.package;
          default = camoufox-bin.camofox-browser;
        };
        host = mkOption {
          type = types.singleLineStr;
          default = "::1";
        };
        port = mkOption {
          type = types.port;
        };
        stateDir = mkOption {
          type = types.singleLineStr;
        };
        cacheDir = mkOption {
          type = types.singleLineStr;
        };
        runtimeDir = mkOption {
          type = types.singleLineStr;
        };
        sops.envFile = {
          key = mkOption {
            type = types.singleLineStr;
          };
          sopsFile = mkOption {
            type = types.path;
          };
          path = mkOption {
            type = types.strMatching "^/run/.*[^/]$";
            default = outerCfg.sops.secrets.${cfg.sops.envFile.key}.path;
            readOnly = true;
          };
        };
        netns-id = mkOption {
          type = types.nullOr types.singleLineStr;
        };
        sleep-on-idle-id = mkOption {
          type = types.nullOr types.singleLineStr;
        };
        squid-id = mkOption {
          type = types.nullOr types.singleLineStr;
          default = null;
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    sops.secrets = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.sops.envFile.key} = {
          inherit (cfg.sops.envFile) sopsFile;
          restartUnits = ["${cfg.serviceName}.service"];
        };
      })
      enabled);

    systemd.services = mapAttrs' (_: cfg:
      nameValuePair cfg.serviceName {
        environment = {
          CAMOFOX_HOST = cfg.host;
          CAMOFOX_PORT = toString cfg.port;
          CAMOUFOX_EXECUTABLE = getExe cfg.camoufox.package;
          CAMOFOX_ALLOW_PRIVATE_NETWORK = "false";
          NODE_ENV = "production";
          HOME = "%S/${cfg.stateDir}";
          XDG_CACHE_HOME = "%C/${cfg.cacheDir}";
          XDG_RUNTIME_DIR = "%t/${cfg.runtimeDir}";
        };
        serviceConfig = {
          Type = "exec";
          ExecStart = "${getExe cfg.package} serve";
          EnvironmentFile = [cfg.sops.envFile.path];
          Restart = "on-failure";
          KillMode = "mixed";
          DynamicUser = true;
          WorkingDirectory = "%S/${cfg.stateDir}";
          StateDirectory = cfg.stateDir;
          StateDirectoryMode = "0700";
          CacheDirectory = cfg.cacheDir;
          CacheDirectoryMode = "0700";
          RuntimeDirectory = cfg.runtimeDir;
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
      })
    enabled;

    myOpt.netns = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.netns-id}.set-network-namespace.systemd-services = [cfg.serviceName];
      })
      (filterAttrs (_: cfg: cfg.netns-id != null) enabled));

    myOpt.sleep-on-idle = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.sleep-on-idle-id}.set-cgroup-parent.systemd-services = [cfg.serviceName];
      })
      (filterAttrs (_: cfg: cfg.sleep-on-idle-id != null) enabled));

    myOpt.squid = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.squid-id}.set-env-vars.systemd-services = [cfg.serviceName];
      })
      (filterAttrs (_: cfg: cfg.squid-id != null) enabled));
  };
}
