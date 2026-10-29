{
  config,
  pkgs,
  lib,
  ...
}: {
  services.squid = {
    enable = true;
    validateConfig = true;

    configText = ''
      # Listen only on the host loopback interface.
      http_port 127.0.0.1:3128

      # HTTPS may use CONNECT only to TCP 443.
      acl SSL_ports port 443
      acl Safe_ports port 80 443
      acl CONNECT method CONNECT

      # Explicit destination-domain allowlist.
      #
      # A leading dot includes both the named domain and its subdomains.
      acl allowed_domains dstdomain \
        accounts.google.com \
        oauth2.googleapis.com \
        www.googleapis.com

      # Prevent access to local and private destinations even if DNS
      # for an allowed name is compromised or misconfigured.
      acl forbidden_dst dst \
        0.0.0.0/8 \
        10.0.0.0/8 \
        100.64.0.0/10 \
        127.0.0.0/8 \
        169.254.0.0/16 \
        172.16.0.0/12 \
        192.168.0.0/16 \
        224.0.0.0/4 \
        240.0.0.0/4 \
        ::/128 \
        ::1/128 \
        fc00::/7 \
        fe80::/10

      # Basic safety policy.
      http_access deny !Safe_ports
      http_access deny CONNECT !SSL_ports
      http_access deny forbidden_dst

      # Only approved domain names pass.
      http_access allow allowed_domains

      # Everything else, including ordinary public IP literals, is denied.
      http_access deny all

      # This is an egress gateway, not a cache.
      cache deny all
      access_log stdio:/var/log/squid/access.log
      cache_log /var/log/squid/cache.log
      coredump_dir /var/lib/squid
    '';
  };

  # Squid listens only on loopback, so no public firewall port is needed.
  networking.firewall.enable = true;
}
