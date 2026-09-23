{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; {
  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
  };

  myOpt.cosmic.enable = true;
}
