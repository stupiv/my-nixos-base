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
        serviceName = mkOption {
          type = types.singleLineStr;
          default = cfg.namespace;
          readOnly = true;
        };
        unit = mkOption {
          type = types.singleLineStr;
          default = "${cfg.serviceName}.service";
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
        dns = mkOption {
          type = types.listOf types.singleLineStr;
          default =
            [
              "2606:4700:4700::1111"
              "2606:4700:4700::1001"
            ]
            ++ optional (!cfg.ipv6-only) "1.1.1.1";
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
          sopsFile = mkOption {
            type = types.nullOr types.anything;
            default = null;
          };
          secretsDirName = mkOption {
            type = types.singleLineStr;
            default = name;
          };
          configFile-key = mkOption {
            type = types.singleLineStr;
            default = "${cfg.wireguard.secretsDirName}/wireguardConfigFile";
            readOnly = true;
          };
          configFile = mkOption {
            type = types.nullOr types.path;
            default =
              if cfg.wireguard.sopsFile != null
              then outerCfg.sops.secrets.${cfg.wireguard.configFile-key}.path
              else null;
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
    assertions =
      mapAttrsToList (name: cfg: {
        assertion = cfg.wireguard.enable -> cfg.wireguard.configFile != null;
        message = "myOpt.netns.${name}: wireguard.configFile (or wireguard.sopsFile) must be set when wireguard.enable = true.";
      })
      wgEnabled;

    networking.enableIPv6 = true;
    boot.kernel.sysctl."net.ipv4.ip_forward" = mkDefault 1;
    boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = mkDefault 1;

    sops.secrets = mkMerge (mapAttrsToList (
        _: cfg:
          optionalAttrs (cfg.wireguard.sopsFile != null) {
            ${cfg.wireguard.configFile-key} = {inherit (cfg.wireguard) sopsFile;};
          }
      )
      wgEnabled);

    vpnNamespaces = mkMerge (mapAttrsToList (_: cfg: {
        ${cfg.namespace} = {
          enable = true;
          wireguardConfigFile = cfg.wireguard.configFile;
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
            wantedBy = ["multi-user.target"];
            path = [
              pkgs.iproute2
              pkgs.nftables
              pkgs.coreutils
            ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              ip netns add ${cfg.namespace}
              ip -n ${cfg.namespace} link set dev lo up

              rm -rf /etc/netns/${cfg.namespace}
              mkdir -p /etc/netns/${cfg.namespace}
              printf 'nameserver %s\n' ${escapeShellArgs cfg.dns} > ${cfg.resolvConf}

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

      (mkMerge (mapAttrsToList (_: cfg: {
          "drop-ipv4-in-${cfg.namespace}-ns" = {
            description = "Drop all IPv4 traffic inside network namespace ${cfg.namespace}";
            bindsTo = [cfg.unit];
            after = [cfg.unit];
            wantedBy = [cfg.unit];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              NetworkNamespacePath = cfg.path;
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
