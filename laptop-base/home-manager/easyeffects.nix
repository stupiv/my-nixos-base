{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.myOpt.easyeffects;
  preset_name = "my-default-preset";
in {
  options.myOpt.easyeffects.enable = mkOption {
    type = types.bool;
    default = true;
  };
  config = mkIf cfg.enable {
    services.easyeffects = {
      enable = mkDefault true;
      preset = mkDefault preset_name;
      extraPresets = {
        ${preset_name} = {
          output = {
            blocklist = [];
            plugins_order = [
              "autogain#0"
              "limiter#0"
            ];
            "autogain#0" = {};
            "limiter#0" = {};
          };
          input = {
            blocklist = [];
            plugins_order = [
              "speex#0"
            ];
            "speex#0" = {
              enable-agc = true;
              enable-denoise = true;
              enable-dereverb = true;
              vad.enable = true;
            };
          };
        };
      };
    };
  };
}
