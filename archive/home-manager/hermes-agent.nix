{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  cfg = config.myOpt.hermes-agent;
in {
  imports = [
    inputs.hermes-agent.homeManagerModules.default
  ];
  options.myOpt.hermes-agent.enable = mkOption {
    type = types.bool;
    default = false;
  };
  config = mkIf cfg.enable {
    programs.hermes-agent = {
      enable = mkDefault true;
      desktop.enable = mkDefault true;
    };
    services.hermes-agent = {
      enable = mkDefault true;
      workingDirectory = mkDefault config.xdg.userDirs.download;
      settings = {
        display.busy_input_mode = "steer";
        model = {
          default = "";
          provider = "";
          base_url = "";
          api_mode = "";
        };
        agent = {
          reasoning_effort = "";
          service_tier = "";
        };
      };
    };
  };
}
