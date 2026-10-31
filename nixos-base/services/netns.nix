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
              sytemd-services = mkOption {
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
    virtualisation.oci-containers = mkMerge (
      mapAttrsToList (
        _: cfg: (genAttrs cfg.set-network-namespace.oci-containers (_: {
          extraOptions = ["--network=ns:${cfg.NetworkNamespacePath}"];
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
          (cfg.set-cgroup-parent.systemd-services)
          ++ (map (containerName: "${outerCfg.virtualisation.oci-containers.${containerName}.serviceName}") cfg.set-cgroup-parent.oci-containers)
          ++ (map (containerName: "container@${containerName}") cfg.set-cgroup-parent.nixos-containers)
        ) (_: {
          bindsTo = [cfg.serviceUnit];
          after = [cfg.serviceUnit];
        })))
      enabled)
      ++ (mapAttrsToList (name: cfg: let
          ns = cfg.networkNamespace;
          up = pkgs.writeShellScript "netns-${name}-up" ''
            set -eu
            if ${ip} netns list | ${pkgs.gnugrep}/bin/grep -qw '${ns}'; then
              ${ip} netns del '${ns}'
            fi
            ${ip} netns add '${ns}'
            ${ip} -n '${ns}' link set lo up
          '';
        in {
          ${serviceName} = {
            restartTriggers = [up];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = up;
              ExecStop = "-${ip} netns del '${ns}'";

              NoNewPrivileges = true;
              PrivateTmp = true;
              ProtectHome = true;
              ProtectSystem = "yes";
              CapabilityBoundingSet = [
                "CAP_NET_ADMIN"
                "CAP_NET_RAW"
                "CAP_SYS_ADMIN"
              ];
              RestrictAddressFamilies = [
                "AF_INET"
                "AF_INET6"
                "AF_NETLINK"
                "AF_UNIX"
              ];
              LockPersonality = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              UMask = "0077";
            };
          };
        })
        enabled)
    );
  };
}
