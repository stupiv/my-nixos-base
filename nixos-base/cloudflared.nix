{
  config,
  lib,
  ...
}:
with lib; {
  options.myOpt.cloudflared = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({
      name,
      config,
      ...
    }: {
      options = {
        ingress = mkOption {
          type = types.anything;
        };
      };
    }));
  };

  config = {
    sops.secrets = mapAttrs' (tunnel_id: cfg: (nameValuePair tunnel_id {})) config.myOpt.cloudflared;

    services.cloudflared.enable = mkIf (config.myOpt.cloudflared != {}) true;
    services.cloudflared.tunnels =
      mapAttrs' (tunnel_id: cfg: (nameValuePair tunnel_id {
        inherit (cfg) ingress;
        edgeIPVersion = mkIf (config.services.dnscrypt-proxy.settings.ipv6_servers) (mkDefault "6");
        credentialsFile = config.sops.secrets.${tunnel_id}.path;
        default = mkDefault "http_status:404";
      }))
      config.myOpt.cloudflared;

    systemd.services =
      mapAttrs' (tunnel_id: cfg: (nameValuePair "cloudflared-tunnel-${tunnel_id}" {
        requires = ["dnscrypt-proxy.service"];
        after = ["dnscrypt-proxy.service"];
        unitConfig = {
          StartLimitIntervalSec = mkDefault "10";
          StartLimitBurst = mkDefault "5";
        };
        serviceConfig = {
          Restart = mkDefault "on-failure";
          RestartMaxDelaySec = mkDefault "5min";
          RestartSteps = mkDefault "10";
          RestartSec = mkDefault "1";
        };
      }))
      config.myOpt.cloudflared;
  };
}
