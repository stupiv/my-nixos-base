let
  preset_name = "default";
in {
  services.easyeffects = {
    enable = true;
    preset = preset_name;
    extraPresets = {
      ${preset_name} = {
        output = {
          blocklist = [];
          plugins_order = [
            "autogain#0"
            "maximizer#0"
          ];
          "autogain#0" = {};
          "maximizer#0" = {};
        };
        input = {
          blocklist = [];
          plugins_order = [
            "autogain#0"
            "rnnoise#0"
            "maximizer#0"
          ];
          "autogain#0" = {};
          "rnnoise#0" = {};
          "maximizer#0" = {};
        };
      };
    };
  };
}
