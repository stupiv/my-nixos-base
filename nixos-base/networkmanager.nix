{config, ...}: let
  cfg = config.myOpt;
in {
  networking.networkmanager.enable = true;
  users.users.${cfg.admin.username}.extraGroups = ["networkmanager"];
}
