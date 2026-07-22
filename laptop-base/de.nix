{
  lib,
  pkgs,
  ...
}:
with lib; {
  environment.systemPackages = with pkgs; [
    stretchly
    onlyoffice-desktopeditors
    copyq
    resources
    qview
    pinta
    mpv
    flameshot
    obs-studio
    bluetui
  ];

  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
  };

  myOpt.cosmic.enable = true;
}
