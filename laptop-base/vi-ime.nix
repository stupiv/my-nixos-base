{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; {
  i18n.inputMethod = {
    enable = mkDefault true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [fcitx5-bamboo];
    };
  };
}
