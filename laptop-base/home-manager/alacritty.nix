{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
in {
  programs.alacritty = {
    enable = mkDefault true;
    settings = {
      # window.startup_mode =  "Maximized";
      colors = {
        # See https://github.com/alacritty/alacritty-theme/blob/master/themes/dracula.toml
        primary = {
          background = "#282a36";
          foreground = "#f8f8f2";
        };
        normal = {
          black = "#000000";
          red = "#ff5555";
          green = "#50fa7b";
          yellow = "#f1fa8c";
          blue = "#bd93f9";
          magenta = "#ff79c6";
          cyan = "#8be9fd";
          white = "#bbbbbb";
        };
        bright = {
          black = "#555555";
          red = "#ff5555";
          green = "#50fa7b";
          yellow = "#f1fa8c";
          blue = "#caa9fa";
          magenta = "#ff79c6";
          cyan = "#8be9fd";
          white = "#ffffff";
        };
      };
    };
  };
}
