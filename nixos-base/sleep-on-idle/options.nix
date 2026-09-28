{lib, ...}:
with lib; let
  mkEndpointOpt = {
    self,
    default-socket-address,
  }: {
    port = mkOption {
      type = types.nullOr types.port;
      default = null;
    };
    listen-address = mkOption {
      type = types.nullOr types.singleLineStr;
      default = "127.0.0.1";
      # default =
      #   if config.networking.enableIPv6
      #   then "[::1]"
      #   else "127.0.0.1";
    };
    socket-address = mkOption {
      type = types.singleLineStr;
      default =
        if self.port != null
        then "${self.listen-address}:${toString self.port}"
        else default-socket-address;
    };
  };
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
                self = config.origin;
                default-socket-address = null;
              };
              proxy =
                (mkEndpointOpt {
                  self = config.proxy;
                  default-socket-address = "/run/sleep-on-idle/${serviceName}/${name}.sock";
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
            self = config.health-check;
            default-socket-address =
              if config.endpoints ? default
              then config.endpoints.default.origin.socket-address
              else null;
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
