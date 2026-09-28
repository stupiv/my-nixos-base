{
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };
  programs.dconf.enable = true; # for home-manager services.easyeffects.enable
}
