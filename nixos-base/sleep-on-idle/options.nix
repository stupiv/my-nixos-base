{
  pkgs,
  lib,
  ...
}:
with lib; let
  inherit (pkgs.myLib) mkEndpointOpt;
in {
  options.myOpt.sleep-on-idle = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({
      name,
      config,
      ...
    }: let
      inherit (config) serviceName;
    in {
      options = {
        serviceName = mkOption {
          type = types.singleLineStr;
          default = name;
          readOnly = true;
        };
        endpoints = mkOption {
          default = {};
          type = types.attrsOf (types.submodule ({
            name,
            config,
            ...
          }: {
            options = {
              origin = mkEndpointOpt {
                cfg = config.origin;
                ipv6-brackes = false; # proxyd dial target: no brackets
              };
              proxy =
                (mkEndpointOpt {
                  cfg = config.proxy;
                  default-ip-socket = "/run/sleep-on-idle/${serviceName}/${name}.sock";
                  ipv6-brackes = true; # ListenStream=: brackets required
                })
                // {
                  name = mkOption {
                    type = types.singleLineStr;
                    default = "${serviceName}-proxy-${name}";
                    readOnly = true;
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
            cfg = config.health-check;
            default-ip-socket =
              if config.endpoints ? default
              then config.endpoints.default.origin.ip-socket
              else null;
            ipv6-brackes = true; # curl URL: brackets required
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
        dependsOn = mkOption {
          type = types.listOf types.singleLineStr;
          default = [];
          example = [
            "a-service-without-dot-service"
          ];
        };
        sliceName = mkOption {
          type = types.nullOr types.singleLineStr;
          default =
            if config.dependsOn != []
            then serviceName
            else null;
          readOnly = true;
        };
        thawName = mkOption {
          type = types.singleLineStr;
          default = "${serviceName}-thaw";
          readOnly = true;
        };
        freezeName = mkOption {
          type = types.singleLineStr;
          default = "${serviceName}-freeze";
          readOnly = true;
        };
        SLICE_or_SERVICE = mkOption {
          type = types.nullOr types.singleLineStr;
          default =
            if config.sliceName != null
            then "${config.sliceName}.slice"
            else "${serviceName}.service";
          readOnly = true;
        };
      };
    }));
  };
}
