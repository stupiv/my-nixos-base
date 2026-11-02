{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.netns;
  ip = "${pkgs.iproute2}/bin/ip";
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
            networkNamespace = mkOption {
              type = types.singleLineStr;
              default = builtins.substring 0 7 (builtins.hashString "sha256" name);
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
            NetworkNamespacePath = mkOption {
              type = types.singleLineStr;
              default = "/run/netns/${cfg.networkNamespace}";
              readOnly = true;
            };
          };
        }
      )
    );
  };
  config = mkIf (enabled != {}) {
    containers = mkMerge (
      mapAttrsToList (
        _: cfg: (genAttrs cfg.set-network-namespace.nixos-containers (_: {
          inherit (cfg) networkNamespace;
        }))
      )
      enabled
    );
    virtualisation.oci-containers.containers = mkMerge (
      mapAttrsToList (
        _: cfg: (genAttrs cfg.set-network-namespace.oci-containers (_: {
          networks = ["ns:${cfg.NetworkNamespacePath}"];
        }))
      )
      enabled
    );
    systemd.services = mkMerge (
      (mapAttrsToList (_: cfg: (genAttrs cfg.set-network-namespace.systemd-services (_: {
          serviceConfig = {
            inherit (cfg) NetworkNamespacePath;
            InaccessiblePaths = [
              "/run/nscd"
              "/run/resolvconf"
            ];
          };
        })))
        enabled)
      ++ (mapAttrsToList (_: cfg: (genAttrs (
          (cfg.set-network-namespace.systemd-services)
          ++ (map (containerName: "${outerCfg.virtualisation.oci-containers.containers.${containerName}.serviceName}") cfg.set-network-namespace.oci-containers)
          ++ (map (containerName: "container@${containerName}") cfg.set-network-namespace.nixos-containers)
        ) (_: {
          bindsTo = [cfg.serviceUnit];
          after = [cfg.serviceUnit];
        })))
      enabled)
      ++ (mapAttrsToList (name: cfg: let
          ns = cfg.networkNamespace;
          up = pkgs.writeShellScript "${cfg.serviceName}-up" ''
            set -eu
            if ${ip} netns list | ${pkgs.gnugrep}/bin/grep -qw '${ns}'; then
              ${ip} netns del '${ns}'
            fi
            ${ip} netns add '${ns}'
            ${ip} -n '${ns}' link set lo up
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
