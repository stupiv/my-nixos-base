{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.netns;
  ipv4Egress = filterAttrs (_: cfg: cfg.public-egress.ipv4.enable) enabled;
  ipv6Egress = filterAttrs (_: cfg: cfg.public-egress.ipv6.enable) enabled;
  egress = ipv4Egress // ipv6Egress;
  octet = "(0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])";
  ipv4Type = types.strMatching "${octet}([.]${octet}){3}";
  ipv6Type = types.strMatching "([[:xdigit:]]{0,4}:){1,8}[[:xdigit:]]{0,4}";
  ipv4Endpoints = concatMap (cfg: with cfg.public-egress.ipv4; [address gateway]) (attrValues ipv4Egress);
  ipv6Endpoints =
    map (addr: (builtins.tryEval (lib.network.ipv6.fromString addr).address).value)
    (concatMap (cfg: with cfg.public-egress.ipv6; [address gateway]) (attrValues ipv6Egress));
  ip = getExe pkgs.iproute2;
  nft = getExe pkgs.nftables;
  grep = getExe pkgs.gnugrep;
in {
  options.myOpt.netns = mkOption {
    default = {};
    type = types.attrsOf (
      types.submodule (
        {name, ...} @ innerArgs: let
          cfg = innerArgs.config;
        in {
          options = {
            enable = mkOption {
              type = types.bool;
              default = true;
            };
            ipv4.disable = mkOption {
              type = types.bool;
            };
            public-egress.ipv4 = mkOption {
              default = {};
              type = types.submodule ({options, ...}: {
                options = {
                  enable = mkOption {
                    type = types.bool;
                    default = options.address.isDefined || options.gateway.isDefined;
                    defaultText = literalExpression "options.address.isDefined || options.gateway.isDefined";
                    description = "Setting either endpoint enables this family by default; both endpoints are required when enabled.";
                  };
                  address = mkOption {type = ipv4Type;};
                  gateway = mkOption {type = ipv4Type;};
                };
              });
              description = ''
                Set the namespace address and host gateway to two unused private IPv4 addresses (RFC 1918) without prefixes.
                Generate a candidate pair (address first, gateway second):
                `python3 -c 'from ipaddress import IPv4Address; from secrets import randbits; n = IPv4Address("10.0.0.0") + (randbits(22) << 2); print(n + 2, n + 1)'`
              '';
            };
            public-egress.ipv6 = mkOption {
              default = {};
              type = types.submodule ({options, ...}: {
                options = {
                  enable = mkOption {
                    type = types.bool;
                    default = options.address.isDefined || options.gateway.isDefined;
                    defaultText = literalExpression "options.address.isDefined || options.gateway.isDefined";
                    description = "Setting either endpoint enables this family by default; both endpoints are required when enabled.";
                  };
                  address = mkOption {type = ipv6Type;};
                  gateway = mkOption {type = ipv6Type;};
                };
              });
              description = ''
                Set the namespace address and host gateway to two unused locally assigned IPv6 addresses in fd00::/8 without prefixes.
                Generate a candidate pair (address first, gateway second):
                `python3 -c 'from ipaddress import IPv6Address; from secrets import randbits; n = IPv6Address("fd00::") + (randbits(40) << 80); print(n + 2, n + 1)'`
              '';
            };
            set-network-namespace = {
              systemd-services = mkOption {
                type = types.listOf types.singleLineStr;
              };
              oci-containers = mkOption {
                type = types.listOf types.singleLineStr;
              };
              nixos-containers = mkOption {
                type = types.listOf types.singleLineStr;
              };
            };
            ns = mkOption {
              type = types.singleLineStr;
              default = builtins.substring 0 7 (builtins.hashString "sha256" name);
            };
            nsPath = mkOption {
              type = types.singleLineStr;
              default = "/run/netns/${cfg.ns}";
              readOnly = true;
            };
            serviceName = mkOption {
              type = types.singleLineStr;
              default = "netns-${name}";
            };
            serviceUnit = mkOption {
              type = types.singleLineStr;
              default = "${cfg.serviceName}.service";
              readOnly = true;
            };
          };
        }
      )
    );
  };
  config = mkIf (enabled != {}) {
    assertions = [
      {
        assertion = all (addr: addr != false && builtins.match "fd[[:xdigit:]]{2}:.*" addr != null) ipv6Endpoints;
        message = "IPv6 egress addresses and gateways must be locally assigned unique-local addresses in fd00::/8.";
      }
      {
        assertion = allUnique ipv6Endpoints;
        message = "IPv6 egress addresses and gateways must be unique across namespace links.";
      }
      {
        assertion = all (addr: builtins.match "(10|172[.](1[6-9]|2[0-9]|3[01])|192[.]168)[.].*" addr != null) ipv4Endpoints;
        message = "IPv4 egress addresses and gateways must be in 10.0.0.0/8, 172.16.0.0/12, or 192.168.0.0/16.";
      }
      {
        assertion = all (cfg: !cfg.ipv4.disable) (attrValues ipv4Egress);
        message = "IPv4 egress requires ipv4.disable = false.";
      }
      {
        assertion = allUnique ipv4Endpoints;
        message = "IPv4 egress addresses and gateways must be unique across namespace links.";
      }
    ];
    networking.nat = mkIf (egress != {}) {
      enable = true;
      enableIPv6 = mkIf (ipv6Egress != {}) true;
      internalIPs = mapAttrsToList (_: cfg: "${cfg.public-egress.ipv4.address}/32") ipv4Egress;
      internalIPv6s = mapAttrsToList (_: cfg: "${cfg.public-egress.ipv6.address}/128") ipv6Egress;
    };
    containers = mkMerge (
      mapAttrsToList (
        _: cfg: (genAttrs cfg.set-network-namespace.nixos-containers (_: {
          networkNamespace = cfg.nsPath;
        }))
      )
      enabled
    );
    virtualisation.oci-containers.containers = mkMerge (
      mapAttrsToList (
        _: cfg: (genAttrs cfg.set-network-namespace.oci-containers (_: {
          networks = ["ns:${cfg.nsPath}"];
        }))
      )
      enabled
    );
    systemd.services = mkMerge (
      (mapAttrsToList (_: cfg: (genAttrs cfg.set-network-namespace.systemd-services (_: {
          serviceConfig = {
            NetworkNamespacePath = cfg.nsPath;
            InaccessiblePaths = [
              "/run/nscd"
              "/run/resolvconf"
            ];
          };
        })))
        enabled)
      ++ (mapAttrsToList (_: cfg: (genAttrs (
          (cfg.set-network-namespace.systemd-services)
          ++ (map (oci-con: outerCfg.virtualisation.oci-containers.containers.${oci-con}.serviceName) cfg.set-network-namespace.oci-containers)
          ++ (map (nixos-con: "container@${nixos-con}") cfg.set-network-namespace.nixos-containers)
        ) (_: {
          bindsTo = [cfg.serviceUnit];
          after = [cfg.serviceUnit];
        })))
      enabled)
      ++ (mapAttrsToList (name: cfg: let
          inherit (cfg) ns;
          link = "ne-${builtins.substring 0 12 (builtins.hashString "sha256" name)}";
          inherit (cfg.public-egress) ipv4 ipv6;
          up = pkgs.writeShellScript "${cfg.serviceName}-up" ''
            set -eu
            if ${ip} netns list | ${grep} -qw '${ns}'; then
              ${ip} netns del '${ns}'
            fi
            ${ip} netns add '${ns}'
            ${ip} -n '${ns}' link set lo up

            ${optionalString (hasAttr name egress) ''
              ${ip} link add ${link} type veth peer name eth0 netns '${ns}'
              ${ip} link set ${link} up
              ${ip} -n '${ns}' link set eth0 up
              ${optionalString (ipv6.enable) ''
                ${ip} -6 addr add ${ipv6.gateway} peer ${ipv6.address}/128 dev ${link} nodad
                ${ip} -6 -n '${ns}' addr add ${ipv6.address} peer ${ipv6.gateway}/128 dev eth0 nodad
                ${ip} -6 -n '${ns}' route add default via ${ipv6.gateway} dev eth0
              ''}
              ${optionalString (ipv4.enable) ''
                ${ip} -4 addr add ${ipv4.gateway} peer ${ipv4.address}/32 dev ${link}
                ${ip} -4 -n '${ns}' addr add ${ipv4.address} peer ${ipv4.gateway}/32 dev eth0
                ${ip} -4 -n '${ns}' route add default via ${ipv4.gateway} dev eth0
              ''}
            ''}
            ${optionalString (cfg.ipv4.disable) ''
              ${ip} netns exec '${ns}' ${nft} -f ${pkgs.writeText "disable-ipv4.nft" ''
                table ip filter {
                  chain output {
                    type filter hook output priority 0;
                    policy drop;
                  }
                  chain input {
                    type filter hook input priority 0;
                    policy drop;
                  }
                  chain forward {
                    type filter hook forward priority 0;
                    policy drop;
                  }
                }
              ''}
            ''}
          '';
        in {
          ${cfg.serviceName} = {
            restartTriggers = [up];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = up;
              ExecStop = "-${ip} netns del '${ns}'";

              NoNewPrivileges = true;
              CapabilityBoundingSet = ["CAP_NET_ADMIN" "CAP_SYS_ADMIN"];
              RestrictAddressFamilies = ["AF_NETLINK" "AF_UNIX"];
              IPAddressDeny = "any";
              LockPersonality = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              MemoryDenyWriteExecute = true;
              SystemCallArchitectures = "native";
              KeyringMode = "private";
              RemoveIPC = true;
              ProtectClock = true;
              UMask = "0077";
            };
          };
        })
        enabled)
    );
  };
}
