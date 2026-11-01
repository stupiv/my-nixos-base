{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  inherit (pkgs.myLib) mkEndpointOpt;
in {
  options.myOpt.sleep-on-idle = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        sliceName = mkOption {
          default = name;
        };
        sliceUnit = mkOption {
          default = "${cfg.sliceName}.slice";
          readOnly = true;
        };
        set-cgroup-parent = {
          systemd-services = mkOption {
            type = types.listOf types.singleLineStr;
          };
          oci-containers = mkOption {
            type = types.listOf types.singleLineStr;
          };
        };
        endpoints = mkOption {
          default = {};
          type = types.attrsOf (types.submodule ({name, ...} @ endPointArgs: {
            options = {
              origin = mkEndpointOpt {
                cfg = endPointArgs.config.origin;
                ipv6-brackets = false; # proxyd dial target: no brackets
              };
              proxy =
                (mkEndpointOpt {
                  cfg = endPointArgs.config.proxy;
                  default-ip-socket = "/run/sleep-on-idle/${cfg.sliceName}/${endPointArgs.name}.sock";
                  ipv6-brackets = true; # ListenStream=: brackets required
                })
                // {
                  name = mkOption {
                    type = types.singleLineStr;
                    default = "${cfg.sliceName}-proxy-${endPointArgs.name}";
                  };
                };
            };
          }));
        };
        exit-idle-time = mkOption {
          type = types.int;
          default = 5 * 60;
        };
        TimeoutStartSec = mkOption {
          type = types.int;
          default = 30;
        };
        health-check =
          (mkEndpointOpt {
            cfg = cfg.health-check;
            default-ip-socket = cfg.endpoints.default.origin.ip-socket;
            ipv6-brackets = true; # curl URL: brackets required
          })
          // {
            sleep = mkOption {
              type = types.singleLineStr;
              default = "1";
            };
            path = mkOption {
              type = types.singleLineStr;
            };
          };
        freezeName = mkOption {
          type = types.singleLineStr;
          default = "${cfg.sliceName}-freeze";
        };
        freezeUnit = mkOption {
          default = "${cfg.freezeName}.service";
          readOnly = true;
        };
      };
    }));
  };
}
