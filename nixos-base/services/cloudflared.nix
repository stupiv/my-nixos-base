{
  config,
  lib,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (name: cfg: cfg.enable) outerCfg.myOpt.cloudflared;
in {
  options.myOpt.cloudflared = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({
        name,
        config,
        ...
      } @ innerArgs: let
        cfg = innerArgs.config;
      in {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
          };
          tunnel-id = mkOption {
            type = types.anything;
          };
          sops.tunnel-credentials = {
            key = mkOption {
              type = types.anything;
              default = cfg.tunnel-id;
            };
            sopsFile = mkOption {
              type = types.anything;
            };
          };
          tunnelCfg = mkOption {
            type = types.anything;
            default = {};
          };
        };
      }));
  };
  config = mkIf (enabled != {}) {
    sops.secrets =
      mapAttrs' (name: cfg: (nameValuePair cfg.sops.tunnel-credentials.key {
        inherit (cfg.sops.tunnel-credentials) sopsFile;
      }))
      config.myOpt.cloudflared;

    services.cloudflared.enable = true;
    services.cloudflared.tunnels =
      mapAttrs' (name: cfg: (nameValuePair cfg.tunnel-id (mkMerge [
        cfg.tunnelCfg
        {
          inherit (cfg.tunnelCfg) ingress;
          edgeIPVersion =
            if (config.myOpt.dnscrypt.ipv6.disable)
            then "4"
            else "6";
          credentialsFile = config.sops.secrets.${cfg.sops.tunnel-credentials.key}.path;
          default = "http_status:404";
        }
      ])))
      config.myOpt.cloudflared;

    systemd.services =
      mapAttrs' (name: cfg: (nameValuePair "cloudflared-tunnel-${cfg.tunnel-id}" {
        requires = ["dnscrypt-proxy.service"];
        after = ["dnscrypt-proxy.service"];
        unitConfig = {
          StartLimitIntervalSec = "10";
          StartLimitBurst = "5";
        };
        serviceConfig = {
          Restart = "on-failure";
          RestartMaxDelaySec = "5min";
          RestartSteps = "10";
          RestartSec = "1";
        };
      }))
      config.myOpt.cloudflared;
  };
}
