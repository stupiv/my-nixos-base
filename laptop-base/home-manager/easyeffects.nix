{lib, ...}:
with lib; let
  preset_name = "my-default";
in {
  services.easyeffects = {
    preset = preset_name;
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
            "autogain#0"
            "rnnoise#0"
            "limiter#0"
          ];
          "autogain#0" = {};
          "rnnoise#0" = {};
          "limiter#0" = {};
        };
      };
    };
  };
}
