{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.myOpt.dnscrypt;
in {
  options.myOpt.dnscrypt = {
    enable = mkOption {
      type = types.bool;
      default = true;
    };
    ipv6.disable = mkOption {
      type = types.bool;
    };
    filter = mkOption {
      type = types.lines;
      default = '''';
    };
  };

  config = mkIf (cfg.enable) {
    networking.enableIPv6 = true;
    networking.networkmanager.dns = "none"; # OPTIONAL. default networkmanager listens on udp 0.0.0.0:53

    # See https://nixos.wiki/wiki/Encrypted_DNS
    services.dnscrypt-proxy = {
      enable = true;
      # See https://github.com/DNSCrypt/dnscrypt-proxy/blob/master/dnscrypt-proxy/example-dnscrypt-proxy.toml
      settings = {
        sources.public-resolvers = {
          urls = [
            "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
            "https://download.network.info/resolvers-list/v3/public-resolvers.md"
          ];
          minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"; # See https://github.com/DNSCrypt/dnscrypt-resolvers/blob/master/v3/public-resolvers.md
          cache_file = "/var/lib/dnscrypt-proxy/public-resolvers.md";
        };

        block_ipv6 = cfg.ipv6.disable;
        ipv6_servers = true;
        # listen_addresses = ["127.0.0.1:53" "[::1]:53"];
        listen_addresses = ["[::]:53"];

        require_dnssec = true;
        require_nolog = false;
        require_nofilter = true;
        blocked_names.blocked_names_file = pkgs.writeText "filter.txt" cfg.filter;
      };
    };
  };
}
