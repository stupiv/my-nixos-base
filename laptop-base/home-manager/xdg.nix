{config, ...}: let
  inherit (config.xdg.userDirs) download;
in {
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      documents = download;
      music = download;
      pictures = download;
      videos = download;
    };
  };
}
