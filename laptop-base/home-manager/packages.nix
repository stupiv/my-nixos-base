{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  mkFlatpakPath = desktop: "${config.xdg.dataHome}/flatpak/exports/share/applications/${desktop}";
in {
  services.syncthing.enable = mkDefault true;

  services.flatpak.packages = [
  ];
  xdg.mimeApps.defaultApplicationPackages = with pkgs; [
    onlyoffice-desktopeditors
    qview
    mpv
    zed-editor
  ];
  home.packages =
    config.xdg.mimeApps.defaultApplicationPackages
    ++ (with pkgs; [
      pinta
      flameshot
      resources
      kdePackages.krecorder
      cosmic-store
    ]);
  xdg.autostart.entries = [
  ];
}
