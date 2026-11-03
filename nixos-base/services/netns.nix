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
            ns = mkOption {
              type = types.singleLineStr;
              default = builtins.substring 0 7 (builtins.hashString "sha256" name);
            };
            nsPath = mkOption {
              type = types.singleLineStr;
              default = "/run/netns/${cfg.networkNamespace}";
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
