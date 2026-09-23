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
  services.syncthing.enable = true;

  services.flatpak.packages = [
    # "app.zen_browser.zen"
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
      obs-studio
    ]);
  xdg.autostart.entries = [
    # (mkFlatpakPath "app.zen_browser.zen.desktop")
  ];
}
