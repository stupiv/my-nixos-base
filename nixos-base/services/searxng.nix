{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.searxng-compose;
  names = attrNames enabled;
  mkHttpUrl = host: port: let
    bracketedHost =
      if hasPrefix "[" host
      then host
      else if hasInfix ":" host
      then "[${host}]"
      else host;
  in "http://${bracketedHost}:${toString port}";
  toSliceUnit = p:
    if p == null
    then null
    else if hasSuffix ".slice" p
    then p
    else "${p}.slice";
  resolveNetns = nsName: let
    entry = outerCfg.myOpt.netns.${nsName} or null;
  in
    if entry != null
    then {
      inherit (entry) path resolvConf unit;
    }
    else {
      path = "/run/netns/${nsName}";
      resolvConf = "/etc/netns/${nsName}/resolv.conf";
      unit = "${nsName}.service";
    };
in {
  options.myOpt.searxng-compose = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        # services.searx is a singleton module, so the unit name is fixed and
        # the option is kept read-only for consumers (proxy-compose,
        # sleep-on-idle, hermes-agent-compose) that key off a service name.
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "searx";
          readOnly = true;
        };
        package = mkPackageOption pkgs "searxng" {};
        host = mkOption {
          type = types.singleLineStr;
          default = "::1";
        };
        port = mkOption {
          type = types.port;
        };
        url = mkOption {
          type = types.singleLineStr;
          default = mkHttpUrl cfg.host cfg.port;
        };
        settings = mkOption {
          type = types.anything;
          default = {};
        };
        # Name of the sops secret whose content is passed as EnvironmentFile.
        envFile-key = mkOption {
          type = types.nullOr types.singleLineStr;
          default = null;
        };
        cgroup-parent = mkOption {
          type = types.nullOr types.singleLineStr;
          default = null;
        };
        networkNamespace = mkOption {
          type = types.nullOr types.singleLineStr;
          default = null;
        };
        environment = mkOption {
          type = types.attrsOf types.str;
          default = {};
        };
      };
    }));
  };

  config = mkIf (names != []) (let
    name = head names;
    cfg = enabled.${name};
    sliceUnit = toSliceUnit cfg.cgroup-parent;
    ns =
      if cfg.networkNamespace != null
      then resolveNetns cfg.networkNamespace
      else null;
    settings = recursiveUpdate
      {
        use_default_settings = true;
        general = {
          instance_name = "searxng";
          privacypolicy_url = false;
          contact_url = false;
          donation_url = false;
        };
        search = {
          safe_search = 0;
          autocomplete = "";
          default_lang = "auto";
          formats = [
            "html"
            "json"
          ];
        };
        server = {
          bind_address = cfg.host;
          inherit (cfg) port;
          base_url = "${cfg.url}/";
          limiter = false;
          public_instance = false;
          image_proxy = false;
          method = "GET";
        };
      }
      cfg.settings;
  in {
    assertions = [
      {
        assertion = length names == 1;
        message = "myOpt.searxng-compose: services.searx is a singleton, enable at most one instance (enabled: ${concatStringsSep ", " names})";
      }
    ];

    # Only declares the secret; the sops file stays with the caller
    # (sops.secrets.<key>.sopsFile or sops.defaultSopsFile).
    sops.secrets =
      optionalAttrs (cfg.envFile-key != null) {
        ${cfg.envFile-key} = {};
      };

    services.searx = {
      enable = true;
      inherit (cfg) package settings;
      environmentFile =
        if cfg.envFile-key != null
        then outerCfg.sops.secrets.${cfg.envFile-key}.path
        else null;
    };

    systemd.services.searx = mkMerge [
      {
        inherit (cfg) environment;
        serviceConfig =
          {
            ProtectHome = true;
            ProtectClock = true;
            ProtectHostname = true;
            ProtectKernelLogs = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            LockPersonality = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
          }
          // optionalAttrs (sliceUnit != null) {
            Slice = sliceUnit;
          }
          // optionalAttrs (ns != null) {
            NetworkNamespacePath = ns.path;
            BindReadOnlyPaths = ["${ns.resolvConf}:/etc/resolv.conf"];
          };
      }
      (mkIf (ns != null) {
        bindsTo = [ns.unit];
        after = [ns.unit];
      })
    ];
  });
}
