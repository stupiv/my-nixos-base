{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.netns;
  wgEnabled = filterAttrs (_: cfg: cfg.wireguard.enable) enabled;
  plainEnabled = filterAttrs (_: cfg: !cfg.wireguard.enable) enabled;
  ipv6OnlyEnabled = filterAttrs (_: cfg: cfg.ipv6-only) enabled;
  wgSecretKey = name: "${name}/wireguardConfigFile";
in {
  options.myOpt.netns = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
      hash = builtins.hashString "sha256" name;
      o2 = trivial.fromHexString (builtins.substring 0 2 hash);
      o3 = trivial.fromHexString (builtins.substring 2 2 hash);
      ula1 = builtins.substring 4 2 hash;
      ula2 = builtins.substring 6 4 hash;
      ula3 = builtins.substring 10 4 hash;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        namespace = mkOption {
          type = types.singleLineStr;
          default =
            if builtins.stringLength name < 8
            then name
            else "v${builtins.substring 0 6 hash}";
          readOnly = true;
        };
        dnsContainerName = mkOption {
          type = types.singleLineStr;
          default = "${cfg.namespace}-dns";
          readOnly = true;
        };
        serviceName = mkOption {
          type = types.singleLineStr;
          default = cfg.namespace;
          readOnly = true;
        };
        unit = mkOption {
          type = types.singleLineStr;
          default = "container@${cfg.dnsContainerName}.service";
          readOnly = true;
        };
        path = mkOption {
          type = types.singleLineStr;
          default = "/run/netns/${cfg.namespace}";
          readOnly = true;
        };
        resolvConf = mkOption {
          type = types.singleLineStr;
          default = "/etc/netns/${cfg.namespace}/resolv.conf";
          readOnly = true;
        };
        ipv6-only = mkOption {
          type = types.bool;
          default = false;
        };
        sopsFile = mkOption {
          type = types.nullOr types.anything;
          default = null;
        };
        bridgeAddress = mkOption {
          type = types.singleLineStr;
          default = "10.${toString o2}.${toString o3}.1";
        };
        namespaceAddress = mkOption {
          type = types.singleLineStr;
          default = "10.${toString o2}.${toString o3}.2";
        };
        bridgeAddressIPv6 = mkOption {
          type = types.singleLineStr;
          default = "fd${ula1}:${ula2}:${ula3}::1";
        };
        namespaceAddressIPv6 = mkOption {
          type = types.singleLineStr;
          default = "fd${ula1}:${ula2}:${ula3}::2";
        };
        wireguard = {
          enable = mkOption {
            type = types.bool;
            default = false;
          };
          accessibleFrom = mkOption {
            type = types.listOf types.singleLineStr;
            default = [];
          };
          allowedEgress = mkOption {
            type = types.listOf types.singleLineStr;
            default = [];
          };
          portMappings = mkOption {
            type = types.listOf types.anything;
            default = [];
          };
          openVPNPorts = mkOption {
            type = types.listOf types.anything;
            default = [];
          };
        };
      };
    }));
  };

  imports = [
    inputs.vpn-confinement.nixosModules.default
  ];

  config = mkIf (enabled != {}) {
    networking.enableIPv6 = true;
    boot.kernel.sysctl."net.ipv4.ip_forward" = mkDefault 1;
    boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = mkDefault 1;

    sops.secrets = mkMerge (mapAttrsToList (name: cfg: {
        ${wgSecretKey name} = optionalAttrs (cfg.sopsFile != null) {
          inherit (cfg) sopsFile;
        };
      })
      wgEnabled);

    vpnNamespaces = mkMerge (mapAttrsToList (name: cfg: {
        ${cfg.namespace} = {
          enable = true;
          wireguardConfigFile = outerCfg.sops.secrets.${wgSecretKey name}.path;
          inherit
            (cfg)
            bridgeAddress
            namespaceAddress
            bridgeAddressIPv6
            namespaceAddressIPv6
            ;
          inherit
            (cfg.wireguard)
            accessibleFrom
            allowedEgress
            portMappings
            openVPNPorts
            ;
        };
      })
      wgEnabled);

    containers = mkMerge (mapAttrsToList (_: cfg: let
        nsName = cfg.namespace;
      in {
        ${cfg.dnsContainerName} = {
          ephemeral = true;
          privateNetwork = false;
          networkNamespace = cfg.path;
          autoStart = false;
          extraFlags = ["--resolv-conf=off"];
          bindMounts."/etc/netns/${nsName}" = {
            hostPath = "/etc/netns/${nsName}";
            isReadOnly = false;
          };
          config = {...}: {
            imports = [
              ../dnscrypt
              ./ipv6.nix
            ];
            networking.useHostResolvConf = mkOverride 90 false;
            systemd.services.export-netns-resolv-conf = {
              description = "Export in-container dnscrypt resolv.conf to /etc/netns/${nsName}/resolv.conf";
              wantedBy = ["multi-user.target"];
              after = [
                "etc.service"
                "resolvconf.service"
                "network-local-commands.service"
                "network.target"
                "dnscrypt-proxy.service"
                "nss-lookup.target"
              ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                NoNewPrivileges = true;
                PrivateTmp = true;
                ProtectHome = true;
                ProtectClock = true;
                ProtectKernelLogs = true;
                ProtectKernelModules = true;
                ProtectKernelTunables = true;
                ProtectControlGroups = true;
                LockPersonality = true;
                RestrictRealtime = true;
                RestrictSUIDSGID = true;
                UMask = "0022";
              };
              script = ''
                cat /etc/resolv.conf > /etc/netns/${nsName}/resolv.conf
              '';
            };
            systemd.paths.export-netns-resolv-conf = {
              wantedBy = ["multi-user.target"];
              pathConfig.PathChanged = ["/etc/resolv.conf"];
            };
          };
        };
      })
      enabled);

    systemd.services = mkMerge [
      (mkMerge (mapAttrsToList (_: cfg: let
          tableName = "netns_${replaceStrings ["-"] ["_"] cfg.namespace}";
          natRules = pkgs.writeText "${cfg.namespace}-nat.nft" ''
            table inet ${tableName} {
              chain postrouting {
                type nat hook postrouting priority srcnat; policy accept;
                ${optionalString (!cfg.ipv6-only) "ip saddr ${cfg.namespaceAddress} oifname != \"${cfg.namespace}-br\" masquerade"}
                ip6 saddr ${cfg.namespaceAddressIPv6} oifname != "${cfg.namespace}-br" masquerade
              }
              chain forward {
                type filter hook forward priority filter; policy accept;
                iifname "${cfg.namespace}-br" accept
                oifname "${cfg.namespace}-br" ct state established,related accept
              }
            }
          '';
        in {
          ${cfg.serviceName} = {
            description = "Isolated network namespace ${cfg.namespace}";
            after = ["network-online.target"];
            wants = ["network-online.target"];
            path = [
              pkgs.iproute2
              pkgs.nftables
              pkgs.coreutils
            ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              NoNewPrivileges = true;
              PrivateTmp = true;
              ProtectHome = true;
              ProtectClock = true;
              ProtectHostname = true;
              ProtectKernelLogs = true;
              ProtectKernelModules = true;
              ProtectControlGroups = true;
              LockPersonality = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              CapabilityBoundingSet = [
                "CAP_NET_ADMIN"
                "CAP_SYS_ADMIN"
              ];
              AmbientCapabilities = [
                "CAP_NET_ADMIN"
                "CAP_SYS_ADMIN"
              ];
            };
            script = ''
              ip netns add ${cfg.namespace}
              ip -n ${cfg.namespace} link set dev lo up

              rm -rf /etc/netns/${cfg.namespace}
              mkdir -p /etc/netns/${cfg.namespace}

              ip link add ${cfg.namespace}-br type bridge
              ${optionalString (!cfg.ipv6-only) "ip addr add ${cfg.bridgeAddress}/24 dev ${cfg.namespace}-br"}
              ip -6 addr add ${cfg.bridgeAddressIPv6}/64 dev ${cfg.namespace}-br
              ip link set dev ${cfg.namespace}-br up

              ip link add veth-${cfg.namespace}-br type veth peer name veth-${cfg.namespace} netns ${cfg.namespace}
              ip link set veth-${cfg.namespace}-br master ${cfg.namespace}-br
              ip link set dev veth-${cfg.namespace}-br up

              ${optionalString (!cfg.ipv6-only) "ip -n ${cfg.namespace} addr add ${cfg.namespaceAddress}/24 dev veth-${cfg.namespace}"}
              ip -n ${cfg.namespace} -6 addr add ${cfg.namespaceAddressIPv6}/64 dev veth-${cfg.namespace}
              ip -n ${cfg.namespace} link set dev veth-${cfg.namespace} up

              ${optionalString (!cfg.ipv6-only) "ip -n ${cfg.namespace} route add default via ${cfg.bridgeAddress} dev veth-${cfg.namespace}"}
              ip -n ${cfg.namespace} -6 route add default via ${cfg.bridgeAddressIPv6} dev veth-${cfg.namespace}

              nft delete table inet ${tableName} 2>/dev/null || true
              nft -f ${natRules}
            '';
            postStop = ''
              nft delete table inet ${tableName} 2>/dev/null || true
              ip netns del ${cfg.namespace} 2>/dev/null || true
              ip link del ${cfg.namespace}-br 2>/dev/null || true
              ip link del veth-${cfg.namespace}-br 2>/dev/null || true
              rm -rf /etc/netns/${cfg.namespace}
            '';
          };
        })
        plainEnabled))

      (mkMerge (mapAttrsToList (_: cfg: let
          baseUnit = "${cfg.serviceName}.service";
          dropUnit = "drop-ipv4-in-${cfg.namespace}-ns.service";
        in {
          "container@${cfg.dnsContainerName}" = {
            bindsTo = [baseUnit];
            after =
              [baseUnit]
              ++ optional cfg.ipv6-only dropUnit;
            wantedBy = [baseUnit];
            preStart = mkBefore ''
              mkdir -p /etc/netns/${cfg.namespace}
              ${optionalString cfg.wireguard.enable ''
                ${pkgs.iproute2}/bin/ip netns exec ${cfg.namespace} ${pkgs.iptables}/bin/iptables -C dns-fw -o lo -j ACCEPT 2>/dev/null \
                  || ${pkgs.iproute2}/bin/ip netns exec ${cfg.namespace} ${pkgs.iptables}/bin/iptables -I dns-fw -o lo -j ACCEPT
                ${pkgs.iproute2}/bin/ip netns exec ${cfg.namespace} ${pkgs.iptables}/bin/ip6tables -C dns-fw -o lo -j ACCEPT 2>/dev/null \
                  || ${pkgs.iproute2}/bin/ip netns exec ${cfg.namespace} ${pkgs.iptables}/bin/ip6tables -I dns-fw -o lo -j ACCEPT
              ''}
            '';
          };
        })
        enabled))

      (mkMerge (mapAttrsToList (_: cfg: {
          "drop-ipv4-in-${cfg.namespace}-ns" = {
            description = "Drop all IPv4 traffic inside network namespace ${cfg.namespace}";
            bindsTo = ["${cfg.serviceName}.service"];
            after = ["${cfg.serviceName}.service"];
            wantedBy = ["${cfg.serviceName}.service"];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              NetworkNamespacePath = cfg.path;
              NoNewPrivileges = true;
              PrivateTmp = true;
              PrivateDevices = true;
              ProtectSystem = "strict";
              ProtectHome = true;
              ProtectClock = true;
              ProtectHostname = true;
              ProtectKernelLogs = true;
              ProtectKernelModules = true;
              ProtectKernelTunables = true;
              ProtectControlGroups = true;
              LockPersonality = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              RestrictAddressFamilies = ["AF_NETLINK"];
              CapabilityBoundingSet = ["CAP_NET_ADMIN"];
              AmbientCapabilities = ["CAP_NET_ADMIN"];
            };
            script = ''
              ${pkgs.nftables}/bin/nft -f ${pkgs.writeText "drop-ipv4.nft" ''
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
            '';
          };
        })
        ipv6OnlyEnabled))
    ];
  };
}
