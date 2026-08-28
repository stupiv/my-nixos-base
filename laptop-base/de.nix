{
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; {
  imports = [inputs.nix-flatpak.nixosModules.nix-flatpak];
  services.flatpak = {
    enable = true;
    update.auto = {
      enable = true;
      onCalendar = "*-05,11-*";
    };
    packages = [
      "app.zen_browser.zen"
    ];
  };

  environment.systemPackages = with pkgs; [
    onlyoffice-desktopeditors
    resources
    qview
    pinta
    mpv
    flameshot
    obs-studio
    zed-editor
  ];

  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
  };

  myOpt.cosmic.enable = true;
}
