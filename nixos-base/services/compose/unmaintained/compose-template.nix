{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  enabled-compose-template = filterAttrs (_: cfg: cfg.enable) config.myOpt.compose-template;
in {
  options.myOpt.compose-template = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({
      name,
      config,
      ...
    }: {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        modules = {
          proxy-compose = mkOption {
            type = types.anything;
          };
        };
        serviceName = mkOption {
          type = types.singleLineStr;
          default = name;
          readOnly = true;
        };
        networkNamespace = mkOption {
          type = types.singleLineStr;
        };
        cgroup-parent = mkOption {
          type = types.singleLineStr;
        };
      };
    }));
  };

  config = {
    myOpt.proxy-compose =
      mapAttrs' (_: cfg: (
        nameValuePair cfg.serviceName
        cfg.proxy-compose
      ))
      enabled-compose-template;
  };
}
