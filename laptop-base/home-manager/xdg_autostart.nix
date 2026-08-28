{pkgs, ...}: {
  xdg = {
    enable = true;
    autostart = {
      enable = true;
      entries = [
        "/var/lib/flatpak/exports/share/applications/app.zen_browser.zen.desktop"
      ];
    };
  };
}
